output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "Needed by future IRSA roles (e.g. AWS Load Balancer Controller)"
  value       = module.eks.oidc_provider_arn
}

output "node_security_group_id" {
  description = "Consumed by repo-db-infra to allow Postgres access from EKS nodes"
  value       = module.eks.node_security_group_id
}
