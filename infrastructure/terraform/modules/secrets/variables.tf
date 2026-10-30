variable "name" {
  description = "Prefix used for SSM parameter names"
  type        = string
}

variable "common_tags" {
  description = "Tags applied to SSM parameters"
  type        = map(string)
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "jwt_secret_key" {
  description = "Ghostfolio JWT signing secret"
  type        = string
  sensitive   = true
}

variable "access_token_salt" {
  description = "Ghostfolio access-token salt"
  type        = string
  sensitive   = true
}
