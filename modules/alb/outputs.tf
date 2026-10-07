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

output "service_target_group_arns" {
  description = "Target groups keyed by documented service name."
  value       = local.service_target_group_arns
}

output "service_listener_rule_arns" {
  description = "Listener rules keyed by documented service name."
  value       = { for name, rule in aws_lb_listener_rule.service : name => rule.arn }
}
