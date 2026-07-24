terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # TODO: configure remote state backend (S3 + DynamoDB lock) once bucket/table are approved.
  # backend "s3" {}
}
