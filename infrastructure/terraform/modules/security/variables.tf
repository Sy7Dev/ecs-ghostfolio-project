variable "name" {
  description = "Prefix used to name security groups"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the security groups will be created"
  type        = string
}

variable "container_port" {
  description = "Port exposed by the Ghostfolio container"
  type        = number
}

variable "common_tags" {
  description = "Tags applied to security groups"
  type        = map(string)
}
