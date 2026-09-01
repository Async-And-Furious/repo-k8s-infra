output "repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "repository_name" {
  description = "Stable ECR repository name consumed by deployment repositories"
  value       = aws_ecr_repository.app.name
}
