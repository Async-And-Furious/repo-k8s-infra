# RFC-005 — Kafka platform

Issue #314 provisions Kafka in KRaft mode with the Bitnami chart pinned to
`32.4.3`. Three controller/broker pods use encrypted `gp3` PVCs and explicit
resource and heap budgets. The chart is internal-only and disables automatic
topic creation.

The platform Terraform reads the environment's Secrets Manager contract
`tc3/kafka/<environment>` (`username`, `password`) and creates the
`kafka-sasl` Kubernetes Secret in the `kafka` namespace without logging
values. The application deployment only creates its namespaced runtime
projection. Topic names and the bootstrap service are Terraform outputs for
consumers.

Runtime HML smoke validation is pending an available cluster; no apply or
cluster mutation is part of local implementation.
