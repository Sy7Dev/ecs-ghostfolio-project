# ============================================================
# General settings
# ============================================================

variable "aws_region" {
  description = "AWS region for the Ghostfolio deployment"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Name prefix for Ghostfolio AWS resources"
  type        = string
  default     = "ghostfolio"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

# ============================================================
# ECS configuration
# ============================================================

variable "container_port" {
  description = "Port exposed by the Ghostfolio container"
  type        = number
  default     = 3333
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 1
}

variable "task_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 1024
}

variable "task_memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 2048
}

# ============================================================
# Application secrets
# Supply your own unique values outside version control.
# Never commit actual secret values to Git.
# ============================================================

variable "postgres_password" {
  description = "Password for the Ghostfolio PostgreSQL database"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.postgres_password) >= 16
    error_message = "The PostgreSQL password must be at least 16 characters long."
  }
}

variable "jwt_secret_key" {
  description = "Secret key used by Ghostfolio to sign JWTs"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.jwt_secret_key) >= 32
    error_message = "The JWT secret must be at least 32 characters long."
  }
}

variable "access_token_salt" {
  description = "Salt used by Ghostfolio for access tokens"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.access_token_salt) >= 32
    error_message = "The access token salt must be at least 32 characters long."
  }
}

variable "domain_name" {
  description = "Public domain name for the Ghostfolio application"
  type        = string
  default     = "ghostfolio.suhayb.co.uk"
}
