terraform {
  # 1.11+ for S3 native state locking (use_lockfile); no DynamoDB table to bootstrap.
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }

  # Partial configuration: bucket/key/region come from backend.hcl, which the
  # workflow generates per environment from the live Lab account ID.
  backend "s3" {}
}
