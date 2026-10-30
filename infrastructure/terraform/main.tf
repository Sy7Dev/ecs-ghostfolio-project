data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_ecr_repository" "ghostfolio" {
  name                 = local.name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

module "network" {
  source = "./modules/network"

  name               = local.name
  common_tags        = local.common_tags
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "secrets" {
  source = "./modules/secrets"

  name              = local.name
  common_tags       = local.common_tags
  postgres_password = var.postgres_password
  jwt_secret_key    = var.jwt_secret_key
  access_token_salt = var.access_token_salt
}

module "security" {
  source = "./modules/security"

  name           = local.name
  common_tags    = local.common_tags
  vpc_id         = module.network.vpc_id
  container_port = var.container_port
}

module "load_balancer" {
  source = "./modules/load-balancer"

  name                  = local.name
  common_tags           = local.common_tags
  domain_name           = var.domain_name
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
  container_port        = var.container_port
}

module "iam" {
  source = "./modules/iam"

  name               = local.name
  common_tags        = local.common_tags
  ssm_parameter_arns = module.secrets.parameter_arns
}

module "ecs" {
  source = "./modules/ecs"

  name                  = local.name
  common_tags           = local.common_tags
  aws_region            = var.aws_region
  task_cpu              = var.task_cpu
  task_memory           = var.task_memory
  desired_count         = var.desired_count
  container_port        = var.container_port
  ecr_repository_url    = aws_ecr_repository.ghostfolio.repository_url
  execution_role_arn    = module.iam.execution_role_arn
  task_role_arn         = module.iam.task_role_arn
  postgres_password_arn = module.secrets.postgres_password_arn
  database_url_arn      = module.secrets.database_url_arn
  jwt_secret_arn        = module.secrets.jwt_secret_arn
  access_token_salt_arn = module.secrets.access_token_salt_arn
  public_subnet_ids     = module.network.public_subnet_ids
  ecs_security_group_id = module.security.ecs_security_group_id
  target_group_arn      = module.load_balancer.target_group_arn

  depends_on = [
    module.iam,
    module.load_balancer
  ]
}
