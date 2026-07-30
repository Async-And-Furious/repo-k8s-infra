variable "environment" {
  description = "Environment name (hml or prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC id from the vpc module"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet ids from the vpc module (nodes and internal load balancers)"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet ids from the vpc module (internet-facing load balancers, if any)"
  type        = list(string)
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}
