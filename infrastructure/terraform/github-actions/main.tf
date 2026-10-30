terraform {
  required_version = ">= 1.10.0"
  backend "s3" {
  bucket       = "ghostfolio-terraform-state-sy7-2026"
  key          = "ghostfolio/github-actions/terraform.tfstate"
  region       = "eu-west-2"
  encrypt      = true
  use_lockfile = true
}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

data "aws_caller_identity" "current" {}

locals {
  repository     = "Sy7Dev/ecs-ghostfolio-project"
  ecr_repository = "ghostfolio-dev"
  ecs_cluster    = "ghostfolio-dev"
  ecs_service    = "ghostfolio-dev"
  task_family    = "ghostfolio-dev"
  execution_role = "ghostfolio-dev-execution-role"
  task_role      = "ghostfolio-dev-task-role"

  account_id = data.aws_caller_identity.current.account_id
  region     = "eu-west-2"

  cluster_arn         = "arn:aws:ecs:${local.region}:${local.account_id}:cluster/${local.ecs_cluster}"
  service_arn         = "arn:aws:ecs:${local.region}:${local.account_id}:service/${local.ecs_cluster}/${local.ecs_service}"
  task_definition_arn = "arn:aws:ecs:${local.region}:${local.account_id}:task-definition/${local.task_family}:*"
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]
}

resource "aws_iam_role" "github_actions" {
  name = "ghostfolio-github-actions-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:${local.repository}:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "ghostfolio-github-actions-deploy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AuthenticateToECR"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "PushGhostfolioImage"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = "arn:aws:ecr:${local.region}:${local.account_id}:repository/${local.ecr_repository}"
      },
      {
        Sid    = "DescribeGhostfolioResources"
        Effect = "Allow"
        Action = [
          "ecs:DescribeClusters",
          "ecs:DescribeServices"
        ]
        Resource = [
          local.cluster_arn,
          local.service_arn
        ]
      },
      {
        Sid      = "RegisterGhostfolioTaskDefinition"
        Effect   = "Allow"
        Action   = ["ecs:RegisterTaskDefinition"]
        Resource = local.task_definition_arn
      },
      {
        Sid      = "DescribeTaskDefinitions"
        Effect   = "Allow"
        Action   = ["ecs:DescribeTaskDefinition"]
        Resource = "*"
      },
      {
        Sid      = "UpdateGhostfolioService"
        Effect   = "Allow"
        Action   = ["ecs:UpdateService"]
        Resource = local.service_arn
      },
      {
        Sid    = "PassEcsTaskRoles"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          "arn:aws:iam::${local.account_id}:role/${local.execution_role}",
          "arn:aws:iam::${local.account_id}:role/${local.task_role}"
        ]
      }
    ]
  })
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC authentication"
  value       = aws_iam_role.github_actions.arn
}
