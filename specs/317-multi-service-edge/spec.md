# Issue 317 — multi-service edge contract

## Scope

Expose one internal ALB with independently addressable target groups and
listener rules for the documented backend services: `os`, `billing`, and
`execucao`. Keep the existing `application` target group, listener default,
and singular outputs as compatibility aliases for the monolith.

## Contract

- `service_target_group_arns` maps service name to target-group ARN.
- `service_listener_rule_arns` maps service name to listener-rule ARN.
- Each service has a configurable path prefix and backend port/health path.
- The default listener action remains the existing application target group.
- API Gateway consumes the selected listener ARN; no AWS/Kubernetes mutation is
  performed by this change.

## Validation

Terraform formatting and static validation must pass. Outputs must preserve
`application_target_group_arn`, `internal_alb_target_group_arn`, and
`application_backend_port`.
