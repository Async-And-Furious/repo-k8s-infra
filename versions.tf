terraform {
  required_version = ">= 1.8.0"

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

  backend "remote" {
    organization = "async_furious"
    workspaces {
      name = "tc3-k8s-hml"
    }
  }
}
