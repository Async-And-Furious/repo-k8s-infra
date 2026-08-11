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

output "cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "load_balancer_controller_role_arn" {
  description = "IRSA role ARN for kube-system/aws-load-balancer-controller"
  value       = aws_iam_role.load_balancer_controller.arn
}

output "node_security_group_id" {
  description = "Consumed by repo-db-infra to allow Postgres access from EKS nodes"
  value       = module.eks.node_security_group_id
}
