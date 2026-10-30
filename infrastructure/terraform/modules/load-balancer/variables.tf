variable "name" {
  description = "Prefix used to name load-balancer resources"
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group ID attached to the load balancer"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the load balancer"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID for the target group"
  type        = string
}

variable "container_port" {
  description = "Port exposed by the Ghostfolio container"
  type        = number
}

variable "common_tags" {
  description = "Tags applied to load-balancer resources"
  type        = map(string)
}

variable "domain_name" {
  description = "Fully qualified domain name for Ghostfolio HTTPS"
  type        = string
}
