output "vpc_id" {
  description = "VPC consumed by repo-db-infra and repo-auth"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnets for EKS and dependent workloads"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnets reserved for internet-facing AWS resources"
  value       = module.vpc.public_subnet_ids
}

output "cluster_name" {
  description = "EKS cluster name consumed by repo-auth and repo-app"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "EKS OIDC provider ARN; null in Academy/LabRole mode"
  value       = module.eks.oidc_provider_arn
}

output "cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "load_balancer_controller_role_arn" {
  value = module.eks.load_balancer_controller_role_arn
}

output "node_security_group_id" {
  description = "Consumed by repo-db-infra's allowed_security_group_ids"
  value       = module.eks.node_security_group_id
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "ecr_repository_name" {
  description = "Stable ECR repository name consumed by deployment repositories"
  value       = module.ecr.repository_name
}
