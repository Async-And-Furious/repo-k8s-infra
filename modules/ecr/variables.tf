variable "environment" {
  description = "Environment name (hml or prod)"
  type        = string
}

variable "force_delete" {
  description = "Allow repository deletion when it still contains images"
  type        = bool
  default     = false
}

variable "services" {
  description = "Service keys with stable ECR repositories"
  type        = set(string)
  default     = ["os", "billing", "execucao"]
}
