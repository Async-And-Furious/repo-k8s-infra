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

  validation {
    condition = alltrue([
      for cidr in var.cluster_endpoint_public_access_cidrs :
      trimspace(cidr) != "" && can(cidrhost(trimspace(cidr), 0))
    ])
    error_message = "cluster_endpoint_public_access_cidrs must contain only nonempty valid CIDRs."
  }

  validation {
    condition     = !var.cluster_endpoint_public_access || length(var.cluster_endpoint_public_access_cidrs) > 0
    error_message = "At least one CIDR is required when cluster_endpoint_public_access is true."
  }
}

variable "eks_cluster_role_arn" {
  description = "Optional existing IAM role ARN for the EKS control plane; leave empty to create one"
  type        = string
  default     = ""

  validation {
    condition     = var.eks_cluster_role_arn == trimspace(var.eks_cluster_role_arn) && (var.eks_cluster_role_arn == "" || can(regex("^arn:[^:]+:iam::[0-9]{12}:role/.+$", var.eks_cluster_role_arn)))
    error_message = "eks_cluster_role_arn must be empty or a valid partition-neutral IAM role ARN."
  }
}

variable "eks_node_role_arn" {
  description = "Optional existing IAM role ARN for EKS managed node groups; leave empty to create one"
  type        = string
  default     = ""

  validation {
    condition     = var.eks_node_role_arn == trimspace(var.eks_node_role_arn) && (var.eks_node_role_arn == "" || can(regex("^arn:[^:]+:iam::[0-9]{12}:role/.+$", var.eks_node_role_arn)))
    error_message = "eks_node_role_arn must be empty or a valid partition-neutral IAM role ARN."
  }
}

variable "load_balancer_controller_role_arn" {
  description = "Optional existing IAM role ARN for the AWS Load Balancer Controller; leave empty to create one"
  type        = string
  default     = ""

  validation {
    condition     = var.load_balancer_controller_role_arn == trimspace(var.load_balancer_controller_role_arn) && (var.load_balancer_controller_role_arn == "" || can(regex("^arn:[^:]+:iam::[0-9]{12}:role/.+$", var.load_balancer_controller_role_arn)))
    error_message = "load_balancer_controller_role_arn must be empty or a valid partition-neutral IAM role ARN."
  }
}
