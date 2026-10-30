variable "name" {
  description = "Prefix used to name network resources"
  type        = string
}

variable "common_tags" {
  description = "Tags applied to network resources"
  type        = map(string)
}

variable "vpc_cidr" {
  description = "CIDR range for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for public subnets"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two availability zones are required."
  }
}
