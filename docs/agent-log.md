# Agent log

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
