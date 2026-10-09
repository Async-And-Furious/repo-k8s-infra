#!/bin/sh
set -eu

usage() { printf '%s\n' "Usage: $0 g1 | g2 [node] [--execute-drain] | g3 [selector] [metrics-pod] [--load-command 'command']"; }
need() { command -v "$1" >/dev/null 2>&1 || { printf 'missing dependency: %s\n' "$1" >&2; exit 2; }; }
need kubectl

case "${1:-}" in
g1)
  need jq
  kubectl get nodes -o json | jq -r '.items[] | [.metadata.name, .status.allocatable.memory] | @tsv' |
    while IFS='\t' read -r node alloc; do
      requests=$(kubectl get pods --all-namespaces --field-selector="spec.nodeName=$node" -o json |
        jq -r '.items[].spec.containers[]?.resources.requests.memory // "0"' |
        awk 'function ki(v, n) { if (v ~ /Ki$/) { sub(/Ki$/, "", v); return v } if (v ~ /Mi$/) { sub(/Mi$/, "", v); return v * 1024 } if (v ~ /Gi$/) { sub(/Gi$/, "", v); return v * 1024 * 1024 } return v / 1024 } { total += ki($0) } END { print total + 0 }')
      alloc_ki=$(printf '%s\n' "$alloc" | awk '{ if ($0 ~ /Ki$/) { sub(/Ki$/, ""); print } else if ($0 ~ /Mi$/) { sub(/Mi$/, ""); print $0 * 1024 } else if ($0 ~ /Gi$/) { sub(/Gi$/, ""); print $0 * 1024 * 1024 } }')
      percent=$(awk -v r="$requests" -v a="$alloc_ki" 'BEGIN { if (a == 0) print "unknown"; else printf "%.1f", r * 100 / a }')
      printf 'G1 node=%s allocatable=%s requests=%sKi usage=%s%% threshold=70%%\n' "$node" "$alloc" "$requests" "$percent"
    done
  ;;
g2)
  node=${2:-}
  [ -n "$node" ] || { usage; exit 2; }
  printf '%s\n' "G2 drain plan (read-only): kubectl drain $node --ignore-daemonsets --delete-emptydir-data --timeout=10m"
  if [ "${3:-}" = "--execute-drain" ]; then
    [ "${CONFIRM_DRAIN:-}" = "I_UNDERSTAND" ] || { printf '%s\n' 'refusing drain: set CONFIRM_DRAIN=I_UNDERSTAND' >&2; exit 2; }
    kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --timeout=10m
  fi
  ;;
g3)
  selector=${2:-app=kafka}
  metrics_pod=${3:-}
  printf 'G3 broker selector: %s\n' "$selector"
  kubectl get pods --all-namespaces -l "$selector" -o wide
  if [ -n "$metrics_pod" ]; then kubectl top pod "$metrics_pod" --containers; else printf '%s\n' 'metrics input not supplied; run kubectl top pod <broker> --containers'; fi
  printf '%s\n' 'Evidence checklist: ~1000 msg/s for 5m; broker working set <=85%% limit; zero broker restarts for 30m.'
  if [ "${4:-}" = "--load-command" ] && [ -n "${5:-}" ]; then printf 'Caller-supplied load command (not executed): %s\n' "$5"; fi
  ;;
*) usage; exit 2;;
esac
