provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "tc3"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# TODO: wire modules/vpc, modules/eks, modules/ecr once network/cluster decisions (RFC-003, RFC-004) are approved.
