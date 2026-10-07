variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "backend_port" {
  type    = number
  default = 3000
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "service_configs" {
  description = "Service edge contract. The os entry aliases the existing application target group."
  type = map(object({
    port              = number
    health_check_path = string
    path_patterns     = list(string)
  }))
  default = {
    os = {
      port              = 3000
      health_check_path = "/api/v1/health/live"
      path_patterns     = ["/api/v1/*"]
    }
    billing = {
      port              = 3001
      health_check_path = "/health"
      path_patterns     = ["/billing/*"]
    }
    execucao = {
      port              = 3002
      health_check_path = "/health"
      path_patterns     = ["/execucao/*"]
    }
  }

  validation {
    condition = contains(keys(var.service_configs), "os") && alltrue([
      for service in values(var.service_configs) : service.port > 0 && length(service.path_patterns) > 0
    ])
    error_message = "service_configs must include os and each service needs a positive port and path pattern."
  }
}

check "backend_port_matches_os_target_group" {
  assert {
    condition     = var.backend_port == var.service_configs.os.port
    error_message = "backend_port must match the effective os target group port."
  }
}
