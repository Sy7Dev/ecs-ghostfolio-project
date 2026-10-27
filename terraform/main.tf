# ============================================================
# Ghostfolio AWS demo
# ECS Fargate + PostgreSQL + Redis + ALB + ECR
# ============================================================

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

# ============================================================
# ECR
# ============================================================

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

# ============================================================
# VPC and public networking
# ============================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.name}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name}-igw"
  })
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name}-public-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ============================================================
# Security groups
# ============================================================

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "Allow public HTTP traffic to the load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Public HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_security_group" "ecs" {
  name        = "${local.name}-ecs-sg"
  description = "Allow app traffic from the ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Ghostfolio from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# ============================================================
# Application Load Balancer
# ============================================================

resource "aws_lb" "main" {
  name               = substr("${local.name}-alb", 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = local.common_tags
}

resource "aws_lb_target_group" "ghostfolio" {
  name        = substr("${local.name}-tg", 0, 32)
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ghostfolio.arn
  }
}

# ============================================================
# CloudWatch logs
# ============================================================

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.name}"
  retention_in_days = 7

  tags = local.common_tags
}

# ============================================================
# IAM roles
# ============================================================

resource "aws_iam_role" "ecs_execution" {
  name = "${local.name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "read_parameters" {
  name = "${local.name}-read-parameters"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameters"
      ]
      Resource = [
        aws_ssm_parameter.postgres_password.arn,
        aws_ssm_parameter.database_url.arn,
        aws_ssm_parameter.jwt_secret.arn,
        aws_ssm_parameter.access_token_salt.arn
      ]
    }]
  })
}

resource "aws_iam_role" "ecs_task" {
  name = "${local.name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

# ============================================================
# Systems Manager Parameter Store
# Terraform state can still contain these sensitive values.
# Protect state and never commit it to Git.
# ============================================================

resource "aws_ssm_parameter" "postgres_password" {
  name        = "/${local.name}/postgres-password"
  description = "Ghostfolio PostgreSQL password"
  type        = "SecureString"
  value       = var.postgres_password

  tags = local.common_tags
}

resource "aws_ssm_parameter" "database_url" {
  name        = "/${local.name}/database-url"
  description = "Ghostfolio database connection string"
  type        = "SecureString"
  value       = "postgresql://ghostfolio:${urlencode(var.postgres_password)}@127.0.0.1:5432/ghostfolio?connect_timeout=300"

  tags = local.common_tags
}

resource "aws_ssm_parameter" "jwt_secret" {
  name        = "/${local.name}/jwt-secret-key"
  description = "Ghostfolio JWT secret"
  type        = "SecureString"
  value       = var.jwt_secret_key

  tags = local.common_tags
}

resource "aws_ssm_parameter" "access_token_salt" {
  name        = "/${local.name}/access-token-salt"
  description = "Ghostfolio access token salt"
  type        = "SecureString"
  value       = var.access_token_salt

  tags = local.common_tags
}

# ============================================================
# ECS cluster
# ============================================================

resource "aws_ecs_cluster" "main" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = local.common_tags
}

# ============================================================
# ECS task definition
# PostgreSQL, Redis and Ghostfolio share the task network.
# Database storage is intentionally ephemeral for this demo.
# ============================================================

resource "aws_ecs_task_definition" "ghostfolio" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
  network_mode = "awsvpc"

  cpu    = tostring(var.task_cpu)
  memory = tostring(var.task_memory)

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "postgres"
      image     = "postgres:15-alpine"
      essential = true

      environment = [
        {
          name  = "POSTGRES_DB"
          value = "ghostfolio"
        },
        {
          name  = "POSTGRES_USER"
          value = "ghostfolio"
        }
      ]

      secrets = [
        {
          name      = "POSTGRES_PASSWORD"
          valueFrom = aws_ssm_parameter.postgres_password.arn
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "pg_isready -U ghostfolio -d ghostfolio"]
        interval    = 10
        timeout     = 5
        retries     = 5
        startPeriod = 30
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "postgres"
        }
      }
    },
    {
      name      = "redis"
      image     = "redis:7-alpine"
      essential = true

      healthCheck = {
        command     = ["CMD", "redis-cli", "ping"]
        interval    = 10
        timeout     = 3
        retries     = 5
        startPeriod = 10
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "redis"
        }
      }
    },
    {
      name      = "ghostfolio"
      image     = "${aws_ecr_repository.ghostfolio.repository_url}:latest"
      essential = true

      dependsOn = [
        {
          containerName = "postgres"
          condition     = "HEALTHY"
        },
        {
          containerName = "redis"
          condition     = "HEALTHY"
        }
      ]

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = aws_ssm_parameter.database_url.arn
        },
        {
          name      = "JWT_SECRET_KEY"
          valueFrom = aws_ssm_parameter.jwt_secret.arn
        },
        {
          name      = "ACCESS_TOKEN_SALT"
          valueFrom = aws_ssm_parameter.access_token_salt.arn
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "REDIS_HOST"
          value = "127.0.0.1"
        },
        {
          name  = "REDIS_PORT"
          value = "6379"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ghostfolio"
        }
      }
    }
  ])

  depends_on = [
    aws_iam_role_policy_attachment.ecs_execution,
    aws_iam_role_policy.read_parameters
  ]

  tags = local.common_tags
}

# ============================================================
# ECS service
# Public IPs avoid NAT Gateway costs.
# Only the ALB can initiate inbound app connections.
# ============================================================

resource "aws_ecs_service" "ghostfolio" {
  name            = local.name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ghostfolio.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ghostfolio.arn
    container_name   = "ghostfolio"
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy.read_parameters
  ]

  tags = local.common_tags
}

# ============================================================
# Outputs
# ============================================================

output "ecr_repository_url" {
  description = "ECR repository URL for the Ghostfolio image"
  value       = aws_ecr_repository.ghostfolio.repository_url
}

output "alb_dns_name" {
  description = "Public DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "ghostfolio_url" {
  description = "HTTP URL for the Ghostfolio demo"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}
