# Vendored EKS module

This is a trimmed, locally patched fork of
[`terraform-aws-modules/eks/aws`](https://github.com/terraform-aws-modules/terraform-aws-eks)
version `20.37.2`. The upstream license is retained in `LICENSE`.

## Local patch

Upstream evaluates the caller session context whenever the module is created:

```hcl
count = local.create ? 1 : 0
```

This fork changes only that session-context condition in `main.tf`:

```hcl
count = local.create && var.enable_cluster_creator_admin_permissions ? 1 : 0
```

AWS Academy's assumed `voclabs` session cannot call `iam:GetRole`. Academy mode
disables cluster-creator admin permissions and supplies `LabRole` explicitly for
cluster access and KMS administration, so the lookup is unnecessary. No upstream
release currently avoids this lookup for that configuration.

## Retained runtime paths

- Root `*.tf`, `templates/`, and `LICENSE`
- `modules/_user_data/*.tf`
- `modules/eks-managed-node-group/*.tf`

Fargate, self-managed node groups, and the unused standalone `aws-auth`,
`hybrid-node-role`, and `karpenter` modules are intentionally omitted.

## Upgrade

1. Replace this directory with the desired upstream release and retain its license.
2. Reapply the exact session-context `count` change above unless upstream no longer
   performs `iam:GetRole` when creator admin permissions are disabled.
3. Remove the same unused modules, root blocks, variables, outputs, generated
   READMEs, and changelog documented here.
4. Run `terraform fmt` and repository validation, then review Terraform addresses
   before adopting the upgrade.
