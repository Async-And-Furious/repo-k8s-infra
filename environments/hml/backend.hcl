bucket         = "tc3-terraform-state"
key            = "repo-k8s-infra/hml/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "tc3-terraform-locks"
encrypt        = true
