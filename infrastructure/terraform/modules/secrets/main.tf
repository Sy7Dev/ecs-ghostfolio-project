resource "aws_ssm_parameter" "postgres_password" {
  name        = "/${var.name}/postgres-password"
  description = "Ghostfolio PostgreSQL password"
  type        = "SecureString"
  value       = var.postgres_password

  tags = var.common_tags
}

resource "aws_ssm_parameter" "database_url" {
  name        = "/${var.name}/database-url"
  description = "Ghostfolio database connection string"
  type        = "SecureString"
  value       = "postgresql://ghostfolio:${urlencode(var.postgres_password)}@127.0.0.1:5432/ghostfolio?connect_timeout=300"

  tags = var.common_tags
}

resource "aws_ssm_parameter" "jwt_secret" {
  name        = "/${var.name}/jwt-secret-key"
  description = "Ghostfolio JWT secret"
  type        = "SecureString"
  value       = var.jwt_secret_key

  tags = var.common_tags
}

resource "aws_ssm_parameter" "access_token_salt" {
  name        = "/${var.name}/access-token-salt"
  description = "Ghostfolio access token salt"
  type        = "SecureString"
  value       = var.access_token_salt

  tags = var.common_tags
}
