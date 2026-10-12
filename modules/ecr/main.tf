resource "aws_ecr_repository" "service" {
  for_each             = var.services
  name                 = "tc3-${each.key}-${var.environment}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "service" {
  for_each   = var.services
  repository = aws_ecr_repository.service[each.key].name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images after 7 days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 7
      }
      action = { type = "expire" }
    }]
  })
}
