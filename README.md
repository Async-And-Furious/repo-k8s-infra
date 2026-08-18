# repo-k8s-infra

Tech Challenge Fase 3 — VPC, EKS and ECR via Terraform.

The EKS module also bootstraps the AWS Load Balancer Controller and Metrics
Server with pinned Helm chart versions. The Kubernetes API is private by
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

### AWS Academy/Lab IAM roles

The EKS module creates the cluster and managed node group IAM roles when the
following variables are empty. Set the `TF_VAR_` environment variables to
reuse existing Lab roles instead:

```bash
export TF_VAR_eks_cluster_role_arn="arn:aws:iam::<ACCOUNT_ID>:role/<CLUSTER_ROLE_NAME>"
export TF_VAR_eks_node_role_arn="arn:aws:iam::<ACCOUNT_ID>:role/<NODE_ROLE_NAME>"
export TF_VAR_load_balancer_controller_role_arn="arn:aws:iam::<ACCOUNT_ID>:role/<LOAD_BALANCER_CONTROLLER_ROLE_NAME>"
```

In AWS Academy/Lab accounts, discover the available role ARN in IAM → Roles
(often `LabRole`), or with `aws iam list-roles`. Do not hardcode account IDs;
use the ARN from the active Lab account. Leave either variable unset or empty
to let Terraform create that role when the credentials permit it.

To reuse an existing Load Balancer Controller IRSA role in GitHub Actions, set
the repository variable (leave it unset or empty to preserve role creation):

```bash
gh variable set LOAD_BALANCER_CONTROLLER_ROLE_ARN --body "arn:aws:iam::<ACCOUNT_ID>:role/<LOAD_BALANCER_CONTROLLER_ROLE_NAME>"
```

## GitHub Actions

Pull requests and pushes to `main` or `develop` run format and validation checks only. Manual dispatch selects `hml` or `prod` and `plan` or `apply`. Plans use an environment-qualified artifact retained for one day; apply downloads that exact artifact and is gated by the protected `hml-apply` or `prod-apply` GitHub Environment. State operations for the same environment do not run concurrently.

Set `AWS_ROLE_ARN` as a repository variable for plans and as an environment variable in each apply environment. The workflow uses GitHub OIDC when the AWS Academy credentials are absent. For an AWS Academy session, configure these repository secrets together:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`

The workflow uses the temporary credentials only when all three secrets are present; otherwise it falls back to OIDC. Rotate the secrets after every AWS Academy session with `gh secret set` (never commit or print their values).

No Terraform apply or infrastructure deployment is claimed by this repository update.

## Naming convention

`tc3-{resource}-{environment}` (e.g. `tc3-eks-hml`).
