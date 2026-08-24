# repo-k8s-infra

Tech Challenge Fase 3 — VPC, EKS and ECR via Terraform.

The EKS module also bootstraps the AWS Load Balancer Controller and Metrics
Server with pinned Helm chart versions. In AWS Academy mode only Metrics
Server is installed. The Kubernetes API is private by
default; set `cluster_endpoint_public_access=true` only when required and
provide a narrow `cluster_endpoint_public_access_cidrs` list.

## Scope

Implements the network (VPC/subnets), Kubernetes cluster (EKS), and container registry (ECR). It is consumed by the database, authentication, and application repositories.

Out of scope: business logic, migrations, database schema, Lambda code.

## Local validation

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

## Bootstrap prerequisites

- Terraform >= 1.8 and AWS CLI configured for the target account.
- Helm provider initialization requires network access to the Terraform
  Registry; the Helm charts are fetched from their pinned repositories during
  apply.
- The AWS Load Balancer Controller uses the Terraform-created IRSA role. The
  `aws` CLI must be available wherever Helm resources are applied because the
  provider uses `aws eks get-token`.
- Do not apply until the EKS cluster and node group prerequisites are ready.

## Backend and plans

Run from the repository root. Each environment uses a separate S3 state key.

```bash
# HML
terraform init -reconfigure -input=false -backend-config=environments/hml/backend.hcl
terraform plan -input=false -var=environment=hml

# PROD
terraform init -reconfigure -input=false -backend-config=environments/prod/backend.hcl
terraform plan -input=false -var=environment=prod
```

### AWS Academy/Lab mode

Academy accounts use temporary credentials and commonly deny IAM writes. Set
these exact variables to reuse the pre-existing `LabRole` for both the EKS
control plane and managed node group:

```bash
export TF_VAR_aws_academy=true
export TF_VAR_manage_iam=false
export TF_VAR_lab_role_arn="arn:aws:iam::<ACCOUNT_ID>:role/LabRole"
```

Use the ARN from the active Lab account; do not hardcode the account ID. Academy
mode does not create IAM roles, OIDC/IRSA resources, or the AWS Load Balancer
Controller Helm release. The application must expose a Kubernetes
`Service` of type `LoadBalancer`; it must not depend on an ALB controller.
Metrics Server remains enabled.

When `manage_iam=false` outside Academy mode, an existing Load Balancer
Controller IRSA role is required. Set the repository variable in that case;
with `manage_iam=true`, leaving it unset or empty preserves Terraform role
creation:

```bash
gh variable set LOAD_BALANCER_CONTROLLER_ROLE_ARN --body "arn:aws:iam::<ACCOUNT_ID>:role/<LOAD_BALANCER_CONTROLLER_ROLE_NAME>"
```

## GitHub Actions

Pull requests and pushes to `main` or `develop` run format and validation checks only on
`ubuntu-latest` without AWS credentials. Manual dispatch selects `hml` or `prod` and
`plan` or `apply`. Normal mode uses the self-hosted runner labels `self-hosted`,
`linux`, and `eks-private` so the private EKS endpoint and Helm provider are reachable.
Academy mode uses `ubuntu-latest`; each Academy plan/apply fetches GitHub's `/meta`
Actions CIDR allowlist and makes the EKS API endpoint public only for those CIDRs.
The allowlist can change, so rerun plan/apply when a session is retried; no unrestricted
CIDR is used. Plans use an environment-qualified artifact retained for one day; apply
downloads that exact artifact and is gated by the protected `hml-apply` or `prod-apply`
GitHub Environment. State operations for the same environment do not run concurrently.

Manual dispatch exposes `aws_academy`, `manage_iam`, and `lab_role_arn`. Select
`aws_academy=true`, `manage_iam=false`, and paste the current LabRole ARN into
`lab_role_arn`. Alternatively set repository variable `LAB_ROLE_ARN`; the
workflow exports it as `TF_VAR_lab_role_arn`. Set `AWS_ROLE_ARN` for the normal
OIDC path. For an AWS Academy session, configure these repository secrets together:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`

The workflow uses the temporary credentials only when all three secrets are present; otherwise it falls back to OIDC. Rotate the secrets after every AWS Academy session with `gh secret set` (never commit or print their values).

No Terraform apply or infrastructure deployment is claimed by this repository update.

## Naming convention

`tc3-{resource}-{environment}` (e.g. `tc3-eks-hml`).
