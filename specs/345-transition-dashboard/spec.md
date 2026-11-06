# #345 — OS transition dashboard increment

## Contract

- Add a time-series widget to the existing `Logs` page; preserve other widgets.
- Filter `Log` records by `logType = 'os.status.transition'` and
  `newStatus IN ('FINISHED', 'CLOSED_WITHOUT_EXECUTION')`; facet by `newStatus`.
- Label results observed, partial and best effort. They are not the total of OS
  status changes. Do not infer ingestion status or assume `appName`.
- `origin/develop` base `914f8b54bf28ca9144fff1f6579d7e64f946b6ea` has no
  `Fluxo distribuído` page; this increment uses `Logs` instead.

## Validation and limits

- Run `git diff --check`; Terraform `fmt -check`/offline `validate` only when
  binaries/providers are already available. No plan, apply, HML, AWS or push.
- This change does not validate NRQL against live New Relic data or prove log
  ingestion.
