output "repository_url" {
  value = aws_ecr_repository.service["os"].repository_url
}

output "repository_name" {
  description = "Stable ECR repository name consumed by deployment repositories"
  value       = aws_ecr_repository.service["os"].name
}

output "repository_urls" {
  value = { for service, repository in aws_ecr_repository.service : service => repository.repository_url }
}

output "repository_names" {
  value = { for service, repository in aws_ecr_repository.service : service => repository.name }
}
