module "eks" {
  source = "../../vendor/eks"

  # Keep the Academy path from querying iam:GetRole for the assumed voclabs session.
  enable_cluster_creator_admin_permissions = var.aws_academy ? false : null

  cluster_name    = "tc3-eks-${var.environment}"
  cluster_version = var.cluster_version

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
      instance_types  = var.node_instance_types
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
