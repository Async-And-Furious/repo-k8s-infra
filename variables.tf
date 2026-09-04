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

variable "cluster_version" {
  description = "Optional EKS Kubernetes version; leave unset to preserve the version reported by an existing cluster"
  type        = string
  default     = null

  validation {
    condition     = var.cluster_version == null || can(regex("^1\\.[0-9]+$", var.cluster_version))
    error_message = "cluster_version must be null or a Kubernetes major.minor version such as 1.30."
  }
}

variable "node_instance_types" {
  description = "Optional EC2 instance types for the managed node group; defaults to t3.micro and t3a.micro for HML and production"
  type        = list(string)
  default     = null

  validation {
    condition = var.node_instance_types == null || (
      length(var.node_instance_types) > 0 &&
      alltrue([for instance_type in var.node_instance_types : trimspace(instance_type) != ""])
    )
    error_message = "node_instance_types must be null or a non-empty list of instance types."
  }
}

variable "node_desired_size" {
  description = "Managed node group desired capacity for HML and production"
  type        = number
  default     = 3

  validation {
    condition     = var.node_desired_size >= 1 && var.node_desired_size == floor(var.node_desired_size)
    error_message = "node_desired_size must be a positive whole number."
  }
}

variable "node_min_size" {
  description = "Managed node group minimum capacity for HML and production"
  type        = number
  default     = 3

  validation {
    condition     = var.node_min_size >= 1 && var.node_min_size == floor(var.node_min_size)
    error_message = "node_min_size must be a positive whole number."
  }
}

variable "node_max_size" {
  description = "Managed node group maximum capacity for HML and production"
  type        = number
  default     = 3

  validation {
    condition     = var.node_max_size >= 1 && var.node_max_size == floor(var.node_max_size)
    error_message = "node_max_size must be a positive whole number."
  }
}

check "node_capacity_configuration" {
  assert {
    condition     = var.node_min_size <= var.node_desired_size && var.node_desired_size <= var.node_max_size
    error_message = "Managed node capacity must satisfy min <= desired <= max."
  }
}

variable "aws_academy" {
  description = "Use AWS Academy compatibility mode and the pre-existing LabRole"
  type        = bool
  default     = false
}

variable "manage_iam" {
  description = "Allow Terraform to create IAM roles and IRSA resources"
  type        = bool
  default     = true
}

variable "lab_role_arn" {
  description = "Existing LabRole ARN used by the EKS control plane and managed node group in Academy mode"
  type        = string
  default     = ""

  validation {
    condition     = var.lab_role_arn == trimspace(var.lab_role_arn) && (var.lab_role_arn == "" || can(regex("^arn:[^:]+:iam::[0-9]{12}:role/.+$", var.lab_role_arn)))
    error_message = "lab_role_arn must be empty or a valid partition-neutral IAM role ARN."
  }
}

check "aws_academy_configuration" {
  assert {
    condition     = !var.aws_academy || (!var.manage_iam && var.lab_role_arn != "")
    error_message = "AWS Academy mode requires manage_iam=false and a non-empty lab_role_arn."
  }
}

check "load_balancer_controller_role_configuration" {
  assert {
    condition     = var.manage_iam || var.aws_academy || var.load_balancer_controller_role_arn != ""
    error_message = "load_balancer_controller_role_arn is required when manage_iam=false outside AWS Academy mode."
  }
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

  validation {
    condition     = length(var.cluster_endpoint_public_access_cidrs) <= 40
    error_message = "cluster_endpoint_public_access_cidrs cannot contain more than 40 CIDRs."
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
