# repo-k8s-infra

Tech Challenge Fase 3 — VPC, EKS and (optionally) ECR via Terraform.

## Scope

Owns network (VPC/subnets) and Kubernetes cluster per HANDOFF.md section 5.2. Consumed by `repo-db-infra` (network) and `repo-auth-serverless`/`repo-application` (cluster/gateway integration).

Out of scope: business logic, migrations, database schema, Lambda code.

## Status

Skeleton only. No `terraform apply` has been run. Modules are placeholders pending RFC-003/RFC-004 approval (API Gateway ownership, VPC ownership).

## Usage

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

## Naming convention

`tc3-{resource}-{environment}` (e.g. `tc3-eks-hml`).
