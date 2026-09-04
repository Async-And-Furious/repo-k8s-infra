data "aws_caller_identity" "current" {}

locals {
  # An Academy session is an assumed "voclabs" session, not LabRole itself, so the
  # caller gets no cluster access from iam_role_arn. Derive the caller's IAM role
  # ARN by splitting the assumed-role ARN rather than calling iam:GetRole, which
  # the lab account denies -- that denial is why
  # enable_cluster_creator_admin_permissions has to stay off here.
  caller_is_assumed_role = length(regexall("assumed-role", data.aws_caller_identity.current.arn)) > 0
  caller_role_arn = local.caller_is_assumed_role ? format(
    "arn:aws:iam::%s:role/%s",
    data.aws_caller_identity.current.account_id,
    split("/", data.aws_caller_identity.current.arn)[1],
  ) : ""

  # Both the session role and LabRole get cluster-admin so Terraform's helm
  # provider and the application pipeline's kubectl can reach the API server.
  academy_access_entries = var.aws_academy ? {
    for arn in distinct(compact([local.caller_role_arn, var.lab_role_arn])) : arn => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  } : {}
}

module "eks" {
  source = "../../vendor/eks"

  # Keep the Academy path from querying iam:GetRole for the assumed voclabs session.
  enable_cluster_creator_admin_permissions = var.aws_academy ? false : true
  access_entries                           = local.academy_access_entries
  kms_key_administrators                   = var.aws_academy ? [var.lab_role_arn] : []

  cluster_name              = "tc3-eks-${var.environment}"
  cluster_version           = var.cluster_version
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  enable_irsa = var.manage_iam && !var.aws_academy

  create_iam_role = var.manage_iam && !var.aws_academy && var.eks_cluster_role_arn == ""
  iam_role_arn    = var.aws_academy ? var.lab_role_arn : (var.eks_cluster_role_arn != "" ? var.eks_cluster_role_arn : null)

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      # AL2023 is supported for the account's EKS 1.30 managed nodes. Values
      # supplied on an individual node group still take precedence.
      ami_type        = "AL2023_x86_64_STANDARD"
      desired_size    = var.node_desired_size
      min_size        = var.node_min_size
      max_size        = var.node_max_size
      create_iam_role = var.manage_iam && !var.aws_academy && var.eks_node_role_arn == ""
      iam_role_arn    = var.aws_academy ? var.lab_role_arn : (var.eks_node_role_arn != "" ? var.eks_node_role_arn : null)
    }
  }
}

data "aws_iam_policy_document" "load_balancer_controller_assume_role" {
  count = var.aws_academy || !var.manage_iam ? 0 : 1
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "load_balancer_controller" {
  count              = var.aws_academy || !var.manage_iam || var.load_balancer_controller_role_arn != "" ? 0 : 1
  name               = "tc3-eks-${var.environment}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.load_balancer_controller_assume_role[0].json
}

data "aws_iam_policy_document" "load_balancer_controller" {
  count = var.aws_academy || !var.manage_iam ? 0 : 1
  statement {
    effect = "Allow"
    actions = [
      "acm:DescribeCertificate", "acm:ListCertificates", "acm:GetCertificate",
      "ec2:AuthorizeSecurityGroupIngress", "ec2:CreateSecurityGroup", "ec2:CreateTags",
      "ec2:DeleteSecurityGroup", "ec2:DescribeAccountAttributes", "ec2:DescribeAddresses",
      "ec2:DescribeInstances", "ec2:DescribeInternetGateways", "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSecurityGroups", "ec2:DescribeSubnets", "ec2:DescribeTags", "ec2:DescribeVpcs",
      "ec2:ModifyInstanceAttribute", "ec2:ModifyNetworkInterfaceAttribute", "ec2:RevokeSecurityGroupIngress",
      "elasticloadbalancing:AddListenerCertificates", "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateListener", "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateRule", "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener", "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteRule", "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DeregisterTargets", "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeListeners", "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeRules", "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeTags", "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth", "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyRule", "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes", "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:RemoveListenerCertificates", "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:SetIpAddressType", "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets", "elasticloadbalancing:SetWebAcl",
      "iam:CreateServiceLinkedRole", "wafv2:GetWebACL", "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL", "wafv2:DisassociateWebACL", "shield:DescribeProtection",
      "shield:GetSubscriptionState", "shield:CreateProtection", "shield:DeleteProtection"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "load_balancer_controller" {
  count  = var.aws_academy || !var.manage_iam || var.load_balancer_controller_role_arn != "" ? 0 : 1
  name   = "aws-load-balancer-controller"
  role   = aws_iam_role.load_balancer_controller[0].id
  policy = data.aws_iam_policy_document.load_balancer_controller[0].json
}
