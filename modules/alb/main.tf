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
  port        = var.backend_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path = var.health_check_path
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
