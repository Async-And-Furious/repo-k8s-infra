#!/bin/sh
set -eu

usage() {
  printf '%s\n' "Usage: $0 g1 | g2 NODE [--execute-drain] | g3 NAMESPACE SELECTOR BROKER-POD MEMORY-LIMIT [--load-command COMMAND] [--execute-load]"
}
need() { command -v "$1" >/dev/null 2>&1 || { printf 'missing dependency: %s\n' "$1" >&2; exit 2; }; }
need kubectl

quantity_mi() {
  awk -v value="$1" 'BEGIN {
    if (value ~ /Ki$/) { sub(/Ki$/, "", value); printf "%.3f", value / 1024; }
    else if (value ~ /Mi$/) { sub(/Mi$/, "", value); printf "%.3f", value; }
    else if (value ~ /Gi$/) { sub(/Gi$/, "", value); printf "%.3f", value * 1024; }
    else { printf "%.3f", value / 1048576; }
  }'
}

g1() {
  need jq
  nodes_json=$(kubectl get nodes -o json)
  pods_json=$(kubectl get pods --all-namespaces -o json)
  failed=0
  for node in $(printf '%s' "$nodes_json" | jq -r '.items[].metadata.name'); do
    alloc=$(printf '%s' "$nodes_json" | jq -r --arg node "$node" '.items[] | select(.metadata.name == $node) | .status.allocatable.memory')
    alloc_mi=$(quantity_mi "$alloc")
    # A pod request is sum(containers), or max(initContainers), whichever is larger.
    requests_mi=$(printf '%s' "$pods_json" | jq -r --arg node "$node" '
      def mem:
        if . == null then 0
        elif test("Ki$") then sub("Ki$"; "") | tonumber / 1024
        elif test("Mi$") then sub("Mi$"; "") | tonumber
        elif test("Gi$") then sub("Gi$"; "") | tonumber * 1024
        elif test("m$") then sub("m$"; "") | tonumber / 1048576 / 1000
        else tonumber / 1048576 end;
      [.items[] | select(.spec.nodeName == $node) |
        ([.spec.containers[]?.resources.requests.memory | mem] | add // 0) as $regular |
        ([.spec.initContainers[]?.resources.requests.memory | mem] | max // 0) as $init |
        (if $init > $regular then $init else $regular end)] | add // 0')
    percent=$(awk -v r="$requests_mi" -v a="$alloc_mi" 'BEGIN { if (a == 0) print "unknown"; else printf "%.1f", r * 100 / a }')
    printf 'G1 node=%s allocatable=%s requests=%.3fMi usage=%s%% threshold=70%%\n' "$node" "$alloc" "$requests_mi" "$percent"
    if [ "$percent" = "unknown" ] || awk -v p="$percent" 'BEGIN { exit !(p > 70) }'; then failed=1; fi
  done
  return "$failed"
}

g2() {
  node=${1:-}
  execute=${2:-}
  [ -n "$node" ] || { usage; exit 2; }
  printf '%s\n' "G2 drain plan (read-only): kubectl drain $node --ignore-daemonsets --delete-emptydir-data --timeout=10m"
  [ "$execute" = "--execute-drain" ] || return 0
  need jq
  [ "${CONFIRM_DRAIN:-}" = "I_UNDERSTAND" ] || { printf '%s\n' 'refusing drain: set CONFIRM_DRAIN=I_UNDERSTAND' >&2; exit 2; }
  uncordon() { kubectl uncordon "$node" >/dev/null 2>&1 || true; }
  trap uncordon EXIT INT TERM
  kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --timeout=10m
   pending=$(kubectl get pods --all-namespaces -o json | jq '[.items[] | select(.status.phase == "Pending")] | length')
   [ "$pending" -eq 0 ] || { printf 'G2 failed: %s Pending pod(s) remain after draining %s\n' "$pending" "$node" >&2; return 1; }
   printf '%s\n' 'G2 passed: no Pending pods remain after the drain.'
}

g3() {
  namespace=${1:-}; selector=${2:-}; broker=${3:-}; limit=${4:-}; shift 4 || true
  [ -n "$namespace" ] && [ -n "$selector" ] && [ -n "$broker" ] && [ -n "$limit" ] || { usage; exit 2; }
  need jq
  printf 'G3 broker selector: %s\n' "$selector"
  kubectl get pods -n "$namespace" -l "$selector" -o wide
  load_command=; execute_load=false
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --load-command) load_command=${2:-}; shift 2;;
      --execute-load) execute_load=true; shift;;
      *) usage; exit 2;;
    esac
  done
  if [ "$execute_load" != true ] || [ -z "$load_command" ]; then
    printf '%s\n' 'G3 is read-only. Supply --load-command COMMAND and --execute-load with CONFIRM_LOAD=I_UNDERSTAND to run the 5-minute window.'
    printf '%s\n' 'Evidence: capture broker metrics/restarts during load and a 30-minute post-load observation; working set must be <=85% of the supplied limit and restarts must remain zero.'
    return 0
  fi
  [ "${CONFIRM_LOAD:-}" = "I_UNDERSTAND" ] || { printf '%s\n' 'refusing load: set CONFIRM_LOAD=I_UNDERSTAND' >&2; exit 2; }
  baseline=$(kubectl get pod "$broker" -n "$namespace" -o json | jq '[.status.containerStatuses[]?.restartCount] | add // 0')
  max_working_set=0
  max_restarts=$baseline
  end=$(( $(date +%s) + 300 ))
  sh -c "$load_command" & load_pid=$!
  sample_broker() {
    current=$(kubectl top pod "$broker" -n "$namespace" --no-headers --containers | awk '{print $4}' | while read -r m; do quantity_mi "$m"; done | awk '{ total += $1 } END { print total + 0 }')
    [ "$(awk -v a="$current" -v b="$max_working_set" 'BEGIN { print (a > b) ? 1 : 0 }')" -eq 1 ] && max_working_set=$current
    restarts=$(kubectl get pod "$broker" -n "$namespace" -o json | jq '[.status.containerStatuses[]?.restartCount] | add // 0')
    [ "$restarts" -gt "$max_restarts" ] && max_restarts=$restarts
    :
  }
  while [ "$(date +%s)" -lt "$end" ]; do
    sample_broker
    sleep 30
  done
  wait "$load_pid" || true
  observation_end=$(( $(date +%s) + 1800 ))
  while [ "$(date +%s)" -lt "$observation_end" ]; do
    sample_broker
    sleep 30
  done
  final=$(kubectl get pod "$broker" -n "$namespace" -o json | jq '[.status.containerStatuses[]?.restartCount] | add // 0')
  printf 'G3 load/observation complete: max_working_set=%.3fMi limit=%s limit_85_percent=%.3fMi restarts_before=%s max_restarts=%s restarts_after=%s observation=30m\n' "$max_working_set" "$limit" "$(awk -v l="$(quantity_mi "$limit")" 'BEGIN { print l * .85 }')" "$baseline" "$max_restarts" "$final"
  awk -v w="$max_working_set" -v l="$(quantity_mi "$limit")" 'BEGIN { exit !(w <= l * .85) }' && [ "$max_restarts" -eq "$baseline" ] && [ "$final" -eq "$baseline" ]
}

case "${1:-}" in
  g1) shift; g1 "$@";;
  g2) shift; g2 "$@";;
  g3) shift; g3 "$@";;
  *) usage; exit 2;;
esac
