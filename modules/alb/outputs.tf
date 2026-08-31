output "arn" {
  value = aws_lb.internal.arn
}

output "dns_name" {
  value = aws_lb.internal.dns_name
}

output "listener_arn" {
  value = aws_lb_listener.http.arn
}

output "security_group_id" {
  value = aws_security_group.internal_alb.id
}

output "target_group_arn" {
  value = aws_lb_target_group.application.arn
}

output "backend_port" {
  value = var.backend_port
}
