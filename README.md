# repo-k8s-infra

Tech Challenge Fase 3 — VPC, EKS and ECR via Terraform.

The EKS module also bootstraps the AWS Load Balancer Controller and Metrics
Server with pinned Helm chart versions. In AWS Academy mode only Metrics
Server is installed. The Kubernetes API is private by default; set
`cluster_endpoint_public_access=true` only when required and provide no more
than 40 narrow entries in `cluster_endpoint_public_access_cidrs`.

## Scope

Implements the network (VPC/subnets), Kubernetes cluster (EKS), and container registry (ECR). It is consumed by the database, authentication, and application repositories.

Out of scope: business logic, migrations, database schema, Lambda code.

## Local validation

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

Local validation does not initialize or contact the remote S3 backend. For a
real local plan, configure AWS credentials and follow the S3 backend steps
below.

## Bootstrap prerequisites

- Terraform >= 1.11 and AWS CLI configured for the target account.
- Helm provider initialization requires network access to the Terraform
  Registry; the Helm charts are fetched from their pinned repositories during
  apply.
- The AWS Load Balancer Controller uses the Terraform-created IRSA role. The
  `aws` CLI must be available wherever Helm resources are applied because the
  provider uses `aws eks get-token`.
- Do not apply until the EKS cluster and node group prerequisites are ready.

## S3 Terraform state and plans

State is stored in the account-qualified S3 bucket
`tc3-tfstate-<ACCOUNT_ID>` under
`repo-k8s-infra/<environment>/terraform.tfstate`. The generated backend
configuration enables S3 native locking with `use_lockfile = true`; no
DynamoDB lock table is used. With AWS credentials configured for the target
account, run from the repository root:

```bash
# HML
bash .github/scripts/bootstrap-backend.sh repo-k8s-infra hml
terraform init -reconfigure -input=false -backend-config=backend.hcl
terraform plan -input=false -var=environment=hml
```

The workflow runs the same backend bootstrap for the selected environment.
The bucket is versioned, encrypted, and blocked from public access.

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

Pull requests and pushes to `main` run format and validation checks only on
`ubuntu-latest` without AWS credentials. A push to the integration branch
`develop` automatically applies HML (using repository variables for its mode).
Manual dispatch selects `hml` or `prod` and `plan`, `apply`, `destroy-plan`, or
`destroy`. Normal mode uses the self-hosted runner labels `self-hosted`,
`linux`, and `eks-private` so the private EKS endpoint and Helm provider are reachable.
Academy HML mode uses `ubuntu-latest`; each run validates the hosted runner's
current public IPv4 address and temporarily restricts the EKS public endpoint
to that single `/32`. The workflow preserves private endpoint access and always
disables public endpoint access after Terraform and Helm finish. No unrestricted
CIDR is used. Manual plan and apply operations run directly against the selected
environment's S3 state. Production runs use the protected GitHub Environment
`production`; its approval rules gate the job. Production apply also requires
`confirm="APPLY PROD"`, and AWS Academy mode is rejected for production. State
operations for the same environment do not run concurrently.

Before backend bootstrap or an EKS endpoint change, the workflow performs a
read-only STS credential check and account-qualified state lookup. It fails
clearly when credentials are missing, expired, or unauthorized. Plans are
saved as `tfplan` and uploaded as a run artifact; apply uses that saved plan.

Destroy operations are available only for Academy HML runs. Both destroy
actions inspect the account-qualified S3 state object without creating or
configuring the bucket; a missing object or state with no resources is a
successful no-op. `destroy-plan` runs a destroy plan only. `destroy` requires
the exact confirmation `DESTROY HML`, creates a saved destroy plan, and applies
that exact plan. Neither action removes the state bucket or state object.
Academy HML permits Terraform to delete the ECR repository with its images;
the production and default ECR behavior continues to reject nonempty deletion.

Manual dispatch exposes `aws_academy`, `manage_iam`, and `lab_role_arn`. Select
`aws_academy=true`, `manage_iam=false`, and paste the current LabRole ARN into
`lab_role_arn`. Alternatively set repository variable `LAB_ROLE_ARN`; the
workflow exports it as `TF_VAR_lab_role_arn`. Set `AWS_ROLE_ARN` for the normal
OIDC path. For an AWS Academy session, configure these repository secrets together:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`

The workflow uses the temporary credentials only when all three secrets are present; otherwise it falls back to OIDC. Rotate the secrets after every AWS Academy session with `gh secret set` (never commit or print their values).

## Naming convention

`tc3-{resource}-{environment}` (e.g. `tc3-eks-hml`).
