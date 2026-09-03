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
