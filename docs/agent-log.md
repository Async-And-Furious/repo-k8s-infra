# Agent log

## 2026-09-03 (Temporary production EKS runner access)

- Allowed only the current GitHub runner `/32` to reach the EKS API during
  production plan/apply, and restored the captured endpoint settings in an
  always-running cleanup step.
- No AWS apply or destroy was performed.

## 2026-09-04 (Free Tier node sizing)

- Defaulted HML and production managed nodes to the AWS Free Tier-eligible
  `t3.micro`, while retaining an explicit `node_instance_types` override.
- Made Helm releases wait for the complete EKS module so they do not race a
  failed or still-unreachable node group.
- Kept subnet selection sourced from the VPC module; no manual subnet inputs,
  AWS apply, or destroy was performed.

## 2026-09-03 (EKS version drift)

- Made the root EKS version optional so existing clusters are not planned toward
  the module's historical 1.30 default, which could invoke an invalid rollback.
- Intentional upgrades remain available through an explicit `cluster_version`.
- No AWS apply or destroy was performed.

## 2026-08-31 (Trivy findings)

- Restricted the internal ALB egress to the VPC CIDR, enabled invalid-header
  dropping, and enabled EKS controller manager and scheduler control-plane logs.
- Kept the approved private HTTP VPC Link listener and documented its narrowly
  scoped AWS-0054 exception; ECR remains on AWS-managed encryption because a
  customer KMS design is not supported by the Academy contract.
- No Terraform apply, commit, or push was performed.

## 2026-08-30 (TargetGroupBinding integration)

- Kept the AWS Load Balancer Controller enabled for HML and production and
  explicitly retained Helm CRD installation so TargetGroupBinding is available.
- Academy mode uses the existing node LabRole rather than an IRSA annotation;
  normal mode continues to use the configured/controller IRSA role.
- Added an explicit internal target-group output and documented the exact
  TargetGroupBinding, Service, port, and listener contract.
- No AWS apply or destroy was performed.

## 2026-08-30 (confirmed delivery target)

- Allowed the same temporary AWS Academy credential set for HML and production;
  production applies remain behind the protected `production` Environment and
  explicit confirmation.
- Added an environment-scoped internal ALB, listener, IP target group, and
  outputs for the Auth/API Gateway and application contracts.
- Made Academy endpoint exposure temporary for existing and new clusters and
  restore the captured private/public/CIDR settings after every plan/apply path.
- No AWS apply or destroy was performed.

## 2026-08-29 (Release path hardening)

- Added automatic HML apply on `develop`, protected `production` environment
  gating, saved Terraform plan artifacts, and read-only AWS/state preflight.
- Academy mode remains LabRole-compatible for HML and is explicitly rejected
  for production; no apply or destroy was performed.
- Published stable ECR repository name output and clarified the existing
  VPC/EKS/OIDC/ECR output contract.

## 2026-08-26 (Direct apply workflow)

- Terraform apply now runs directly after validation; the plan job remains
  limited to explicit plan dispatches.
- Preserved generated auto tfvars, HCP remote state initialization, Academy
  guardrails, environment approvals, and Terraform state locking.
- Terraform apply was not performed.

## 2026-08-24 (Terraform remote backend local execution)

- Switched manual plan/apply to generated local auto tfvars, removing remote
  backend-incompatible CLI variables and plan artifact transfer.
- Preserved Academy public endpoint CIDR validation and normal-mode behavior.
- No Terraform apply was performed.

## 2026-08-24 (HML remote backend initialization)

- Configured the root remote backend for the `tc3-k8s-hml` HCP Terraform
  workspace and removed invalid remote backend CLI overrides from plan/apply.
- Preserved Academy credential, runner, CIDR, LabRole, and IAM behavior.
- No Terraform apply was performed.

## 2026-08-24 (HCP Terraform state)

- Replaced the S3 backend with HCP Terraform's remote state backend using local
  execution and environment-specific `tc3-k8s-*` workspaces.
- Updated CI and runbooks to use `TF_API_TOKEN`; AWS credentials remain in
  GitHub and Academy hosted-runner/CIDR/LabRole behavior is unchanged.
- No Terraform apply, commit, or push was performed.

## 2026-08-13

- Replaced nested Terraform backend blocks with root-consumable HML and PROD backend configuration files while preserving state settings.
- Parameterized manual plan/apply CI by environment, scoped OIDC permissions, preserved plan artifacts for apply, and serialized state operations per environment.
- Updated repository usage and CI documentation.
- No Terraform apply, commit, push, or AWS contact was performed.

## 2026-08-15

- Added pinned Helm bootstrap releases for AWS Load Balancer Controller and
  Metrics Server, using the controller IRSA role.
- Made the EKS API endpoint private by default, with opt-in CIDR-restricted
  public access variables.
- No Terraform apply or remote initialization was performed.

## 2026-08-16

- Added optional EKS cluster and managed node group role ARN inputs for AWS
  Academy/Lab role reuse while preserving Terraform-created role defaults.
- Documented `TF_VAR_eks_cluster_role_arn`, `TF_VAR_eks_node_role_arn`, and Lab
  role ARN discovery.
- No Terraform apply or remote initialization was performed.

## 2026-08-16 (Load Balancer Controller role reuse)

- Added optional root/module Load Balancer Controller role ARN inputs, preserving
  Terraform role creation when empty.
- Wired the GitHub `LOAD_BALANCER_CONTROLLER_ROLE_ARN` variable into the
  canonical lowercase `TF_VAR_load_balancer_controller_role_arn` name and
  documented `gh variable set`.
- No Terraform apply or AWS contact was performed.

## 2026-08-22 (bounded deep-review guardrails)

- Removed duplicate/mismatched Terraform role environment entries and made AWS
  credential selection depend on job environment values; artifact download now
  has explicit `actions: read` permission.
- Added validation for public EKS endpoint CIDRs and optional partition-neutral
  IAM role ARNs. The Load Balancer Controller policy and existing null role
  output contract were intentionally left unchanged.
- No Terraform apply, commit, or push was performed.

## 2026-08-24 (AWS Academy compatibility)

- Added explicit Academy/IAM mode variables and validated LabRole ARN reuse for
  the EKS control plane and managed node group.
- Academy mode disables IAM, OIDC/IRSA, and AWS Load Balancer Controller
  resources while retaining Metrics Server and the Kubernetes LoadBalancer
  service path.
- Added workflow dispatch inputs and documented temporary-credential usage.
- No infrastructure apply, remote initialization, commit, or push was performed.

## 2026-08-24 (Academy workflow integration)

- Added explicit plan/apply dispatch gating and required Academy mode checks.
- Moved manual Terraform plan/apply jobs to the `self-hosted`, `linux`,
  `eks-private` runner labels; credential-free validation remains on
  `ubuntu-latest`.
- Required a pre-existing Load Balancer Controller role when IAM management is
  disabled outside Academy mode.
- No Terraform apply, commit, push, or merge was performed.

## 2026-08-24 (Academy hosted runner access)

- Academy plan/apply now use `ubuntu-latest`; normal mode retains the private
  self-hosted runner labels.
- Academy jobs allowlist the current GitHub Actions CIDRs for the public EKS API
  endpoint without using an unrestricted CIDR; LabRole/IAM-disabled behavior and
  workflow action inputs remain unchanged.
- No Terraform apply, commit, or push was performed.

## 2026-08-24 (Academy IAM session-context fix)

- Vendored the resolved terraform-aws-modules/eks/aws v20.37.2 runtime module,
  including its required nested modules, and gated only its IAM session-context
  data source on creator-admin permissions.
- Academy mode explicitly disables creator-admin permissions while retaining
  LabRole selection and no IAM/IRSA/ALB role creation.
- Terraform fmt, backendless init, and validate passed. AWS Academy plan was
  not run because the local AWS CLI failed before credentials could be checked.
