# VPC module. Owns VPC, subnets, route tables per HANDOFF.md 6.1 (RFC-004).
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = "tc3-vpc-${var.environment}"
  cidr = var.vpc_cidr
  azs  = var.azs

  # /24 per subnet: 2 AZs x (public + private) fits comfortably in a /16.
  public_subnets  = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnets = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 8, i + 10)]

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Single NAT gateway: hml/prod both run one small cluster, not worth
  # one NAT per AZ for this workload. ponytail: revisit if prod needs
  # AZ-isolated egress.
  enable_nat_gateway = true
  single_nat_gateway = true

  # Required by the AWS Load Balancer Controller to auto-discover subnets
  # for internet-facing vs internal ALBs/NLBs.
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                  = "1"
    "kubernetes.io/cluster/tc3-eks-${var.environment}" = "shared"
  }
}
