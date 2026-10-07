data "aws_vpc" "this" {
  id = var.vpc_id
}

resource "aws_security_group" "internal_alb" {
  name        = "tc3-alb-${var.environment}"
  description = "Internal ALB for the EKS application"
  vpc_id      = var.vpc_id

  ingress {
    description = "VPC Link and EKS application traffic"
    from_port   = var.backend_port
    to_port     = var.backend_port
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this.cidr_block]
  }

  ingress {
    description = "API Gateway VPC Link to the HTTP listener"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Allow ALB responses only within the VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.this.cidr_block]
  }
}

resource "aws_lb" "internal" {
  name                       = "tc3-${var.environment}-internal"
  internal                   = true
  load_balancer_type         = "application"
  drop_invalid_header_fields = true
  security_groups            = [aws_security_group.internal_alb.id]
  subnets                    = var.private_subnet_ids
}

resource "aws_lb_target_group" "application" {
  name        = "tc3-${var.environment}-app"
  port        = var.service_configs.os.port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path = var.service_configs.os.health_check_path != "" ? var.service_configs.os.health_check_path : var.health_check_path
  }
}

locals {
  additional_services = { for name, config in var.service_configs : name => config if name != "os" }
  service_target_group_arns = merge(
    { os = aws_lb_target_group.application.arn },
    { for name, target_group in aws_lb_target_group.service : name => target_group.arn },
  )
}

resource "aws_lb_target_group" "service" {
  for_each = local.additional_services

  name        = "tc3-${var.environment}-${each.key}"
  port        = each.value.port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path = each.value.health_check_path
  }
}

#trivy:ignore:AWS-0054: Internal ALB HTTP is the approved API Gateway VPC Link target; this repo has no ACM certificate or domain contract.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.application.arn
  }
}

resource "aws_lb_listener_rule" "service" {
  for_each = var.service_configs

  listener_arn = aws_lb_listener.http.arn
  priority     = index(sort(keys(var.service_configs)), each.key) + 1

  action {
    type             = "forward"
    target_group_arn = local.service_target_group_arns[each.key]
  }

  condition {
    path_pattern {
      values = each.value.path_patterns
    }
  }
}
