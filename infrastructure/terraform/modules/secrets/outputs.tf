output "postgres_password_arn" {
  description = "ARN of the PostgreSQL password parameter"
  value       = aws_ssm_parameter.postgres_password.arn
}

output "database_url_arn" {
  description = "ARN of the database URL parameter"
  value       = aws_ssm_parameter.database_url.arn
}

output "jwt_secret_arn" {
  description = "ARN of the JWT secret parameter"
  value       = aws_ssm_parameter.jwt_secret.arn
}

output "access_token_salt_arn" {
  description = "ARN of the access-token salt parameter"
  value       = aws_ssm_parameter.access_token_salt.arn
}

output "parameter_arns" {
  description = "All SSM parameter ARNs used by Ghostfolio"
  value = [
    aws_ssm_parameter.postgres_password.arn,
    aws_ssm_parameter.database_url.arn,
    aws_ssm_parameter.jwt_secret.arn,
    aws_ssm_parameter.access_token_salt.arn
  ]
}
