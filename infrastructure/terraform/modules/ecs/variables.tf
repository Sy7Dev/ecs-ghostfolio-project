variable "name" {
  description = "Name used for the ECS resources"
  type        = string
}

variable "common_tags" {
  description = "Tags applied to ECS resources"
  type        = map(string)
}

variable "aws_region" {
  description = "AWS region where ECS runs"
  type        = string
}

variable "task_cpu" {
  description = "Fargate task CPU units"
  type        = number
}

variable "task_memory" {
  description = "Fargate task memory in MiB"
  type        = number
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
}

variable "container_port" {
  description = "Ghostfolio application port"
  type        = number
}

variable "ecr_repository_url" {
  description = "ECR repository URL without an image tag"
  type        = string
}

variable "execution_role_arn" {
  description = "ECS execution role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "ECS task role ARN"
  type        = string
}

variable "postgres_password_arn" {
  description = "SSM ARN for the PostgreSQL password"
  type        = string
}

variable "database_url_arn" {
  description = "SSM ARN for the database URL"
  type        = string
}

variable "jwt_secret_arn" {
  description = "SSM ARN for the JWT secret"
  type        = string
}

variable "access_token_salt_arn" {
  description = "SSM ARN for the access-token salt"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "ECS task security group ID"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN"
  type        = string
}

