# Issue #314 — Kafka platform specification

## Goal

Provide a reproducible Kafka KRaft platform for the EKS workloads without
requiring a Kafka operator or cluster mutation during CI validation.

## Contract

- Helm chart: Bitnami Kafka, pinned to `32.4.3`.
- KRaft-only, three brokers/controllers, internal listeners only.
- Authentication is SASL/PLAIN. Credentials are supplied by the existing
  Secrets Manager contract and materialized into a Kubernetes Secret by the
  deployment workflow; no credential value is committed.
- Persistent data uses the existing `gp3` StorageClass, 20Gi per broker.
- Broker requests/limits and JVM heap are explicit and configurable.
- Topics are declared as Terraform/Helm values: `os.events`,
  `os.events.retry`, and `os.events.dlt`, with three partitions and seven-day
  retention. Producers use the retry topic and DLT explicitly.
- Terraform exposes the cluster bootstrap endpoint, secret contract name and
  topic names to consuming repositories.

## Local validation

`terraform fmt -check -recursive`, `terraform init -backend=false`,
`terraform validate`, Helm template/render checks where Helm is installed, and
static assertions over the rendered values. Runtime connectivity and HML
verification remain pending until an approved cluster is available.
