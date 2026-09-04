variable "environment" {
  description = "Environment name (hml or prod)"
  type        = string
}

variable "aws_academy" {
  description = "Use the pre-existing LabRole and disable IAM/IRSA resources"
  type        = bool
  default     = false
}

variable "manage_iam" {
  description = "Allow creation of IAM roles"
  type        = bool
  default     = true
}

variable "lab_role_arn" {
  description = "Existing LabRole ARN for Academy mode"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC id from the vpc module"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet ids from the vpc module (nodes and internal load balancers)"
  type        = list(string)
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

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.micro"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 2
}
