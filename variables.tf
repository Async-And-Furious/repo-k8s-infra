variable "environment" {
  description = "Environment name (hml or prod)"
  type        = string
  validation {
    condition     = contains(["hml", "prod"], var.environment)
    error_message = "environment must be exactly \"hml\" or \"prod\"."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS Kubernetes API endpoint is reachable publicly"
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint"
  type        = list(string)
  default     = []
}

variable "eks_cluster_role_arn" {
  description = "Optional existing IAM role ARN for the EKS control plane; leave empty to create one"
  type        = string
  default     = ""
}

variable "eks_node_role_arn" {
  description = "Optional existing IAM role ARN for EKS managed node groups; leave empty to create one"
  type        = string
  default     = ""
}

variable "load_balancer_controller_role_arn" {
  description = "Optional existing IAM role ARN for the AWS Load Balancer Controller; leave empty to create one"
  type        = string
  default     = ""
}
