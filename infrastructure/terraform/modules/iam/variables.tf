variable "name" {
  description = "Prefix used to name IAM resources"
  type        = string
}

variable "common_tags" {
  description = "Tags applied to IAM resources"
  type        = map(string)
}

variable "ssm_parameter_arns" {
  description = "SSM parameter ARNs that the ECS execution role can read"
  type        = list(string)
}
