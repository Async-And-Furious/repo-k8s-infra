# #345 — Distributed flow dashboard increment

## Contract

- Add `Fluxo distribuído` to the existing dashboard. Preserve all existing pages
  and widgets, including the partial OS transition widget on `Logs`.
- Include throughput and HTTP error rate from `Transaction`, using the existing
  dashboard's evidenced `duration`, `http.statusCode` and `appName` attributes;
  facet by `appName`, without hardcoding service names.
- Include the OS terminal transition series from `Log`, filtered by
  `logType = 'os.status.transition'` and `newStatus IN ('FINISHED',
  'CLOSED_WITHOUT_EXECUTION')`; facet by `newStatus`. Label it partial and
  best-effort, not a complete Saga result.
- Evidence limits: Terraform's existing application page and alert use
  `Transaction`, `duration`, `http.statusCode`; OS deployment reads
  `NEW_RELIC_APP_NAME` from an environment variable and OS transition logs
  expose `service`, not `appName`. Billing's checked-in `main` has no verified
  APM identity/instrumentation; its New Relic event instrumentation exists only
  in a sibling worktree. Execução's named APM environment is likewise found
  only in an unmerged sibling worktree. Therefore FACET appName is a query
  dimension, not proof that all three services emit Transactions or ingest
  under any particular name. No per-service claims or names are inferred.
- `origin/develop` base `914f8b54bf28ca9144fff1f6579d7e64f946b6ea` had no
  `Fluxo distribuído` page. The issue's reduced scope excludes Kafka throughput,
  database widgets, and extraction to `observability.tf`.

## Validation and limits

- Run `git diff --check`; Terraform `fmt -check`/offline `validate` only when
  binaries/providers are already available. No plan, apply, HML, AWS or push.
- Static checks do not validate NRQL against live New Relic data or prove
  transaction/log ingestion or service coverage.
