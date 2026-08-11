module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = "tc3-eks-${var.environment}"
  cluster_version = var.cluster_version

  cluster_endpoint_public_access = true

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  enable_irsa = true

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      desired_size   = var.node_desired_size
      min_size       = var.node_min_size
      max_size       = var.node_max_size
    }
  }
}

data "aws_iam_policy_document" "load_balancer_controller_assume_role" {
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
  name               = "tc3-eks-${var.environment}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.load_balancer_controller_assume_role.json
}

data "aws_iam_policy_document" "load_balancer_controller" {
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
  name   = "aws-load-balancer-controller"
  role   = aws_iam_role.load_balancer_controller.id
  policy = data.aws_iam_policy_document.load_balancer_controller.json
}
