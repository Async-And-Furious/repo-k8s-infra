# EKS module. Owns cluster, node groups per HANDOFF.md 5.2.
# Load balancer/ingress (RFC-003's internal ALB) is a follow-up: it needs
# the AWS Load Balancer Controller running in-cluster (Helm) plus an IAM
# role via IRSA, which is a separate, larger piece of work than the
# cluster itself. enable_irsa below only turns on the OIDC provider so
# that follow-up doesn't need to re-provision the cluster.
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
