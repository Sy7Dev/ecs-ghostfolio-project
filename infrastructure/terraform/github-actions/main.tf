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
  account_id     = data.aws_caller_identity.current.account_id
  region         = "eu-west-2"
  state_bucket   = "ghostfolio-terraform-state-sy7-2026"

  cluster_arn = "arn:aws:ecs:${local.region}:${local.account_id}:cluster/${local.ecs_cluster}"
  service_arn = "arn:aws:ecs:${local.region}:${local.account_id}:service/${local.ecs_cluster}/${local.ecs_service}"

  task_definition_arn = "arn:aws:ecs:${local.region}:${local.account_id}:task-definition/${local.task_family}:*"
}

# GitHub Actions OIDC provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "ab9d0263244dd0326eb67015705a667e79cfe998"
  ]
}

# Existing application deployment role
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

# Existing application deployment permissions
resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "ghostfolio-github-actions-deploy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AuthenticateToECR"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
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
        Sid    = "RegisterGhostfolioTaskDefinition"
        Effect = "Allow"
        Action = [
          "ecs:RegisterTaskDefinition"
        ]
        Resource = local.task_definition_arn
      },
      {
        Sid    = "DescribeTaskDefinitions"
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Sid    = "UpdateGhostfolioService"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService"
        ]
        Resource = local.service_arn
      },
      {
        Sid    = "PassEcsTaskRoles"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          "arn:aws:iam::${local.account_id}:role/${local.execution_role}",
          "arn:aws:iam::${local.account_id}:role/${local.task_role}"
        ]
      }
    ]
  })
}

# Dedicated Terraform GitHub Actions role
resource "aws_iam_role" "github_actions_terraform" {
  name = "ghostfolio-github-actions-terraform"

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

# Terraform infrastructure permissions
resource "aws_iam_role_policy" "github_actions_terraform" {
  name = "ghostfolio-github-actions-terraform"
  role = aws_iam_role.github_actions_terraform.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "TerraformStateBucketListing"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::${local.state_bucket}"
        Condition = {
          StringLike = {
            "s3:prefix" = [
              "ghostfolio/terraform.tfstate",
              "ghostfolio/terraform.tfstate.tflock"
            ]
          }
        }
      },
      {
        Sid      = "TerraformStateBucketLocation"
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation"]
        Resource = "arn:aws:s3:::${local.state_bucket}"
      },
      {
        Sid      = "TerraformStateAccess"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "arn:aws:s3:::${local.state_bucket}/ghostfolio/terraform.tfstate"
      },
      {
        Sid      = "TerraformStateLockAccess"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${local.state_bucket}/ghostfolio/terraform.tfstate.tflock"
      },
      {
        Sid    = "TerraformDiscovery"
        Effect = "Allow"
        Action = [
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeAddresses",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "TerraformNetworkManagement"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "TerraformECRManagement"
        Effect = "Allow"
        Action = [
          "ecr:CreateRepository",
          "ecr:DeleteRepository",
          "ecr:DescribeRepositories",
          "ecr:PutLifecyclePolicy",
          "ecr:DeleteLifecyclePolicy",
          "ecr:ListTagsForResource",
          "ecr:TagResource",
          "ecr:UntagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "TerraformECSManagement"
        Effect = "Allow"
        Action = [
          "ecs:CreateCluster",
          "ecs:DeleteCluster",
          "ecs:DescribeClusters",
          "ecs:ListClusters",
          "ecs:CreateService",
          "ecs:UpdateService",
          "ecs:DeleteService",
          "ecs:DescribeServices",
          "ecs:ListServices",
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTaskDefinitions",
          "ecs:TagResource",
          "ecs:UntagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "TerraformECSIAMManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRolePolicies",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole"
        ]
        Resource = "arn:aws:iam::${local.account_id}:role/ghostfolio-dev-*"
      },
      {
        Sid    = "TerraformPassECSRoles"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          "arn:aws:iam::${local.account_id}:role/ghostfolio-dev-execution-role",
          "arn:aws:iam::${local.account_id}:role/ghostfolio-dev-task-role"
        ]
      },
      {
        Sid    = "TerraformSSMManagement"
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:DeleteParameter",
          "ssm:AddTagsToResource",
          "ssm:RemoveTagsFromResource",
          "ssm:ListTagsForResource"
        ]
        Resource = "arn:aws:ssm:${local.region}:${local.account_id}:parameter/ghostfolio/*"
      },
      {
        Sid    = "TerraformCloudWatchManagement"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy",
          "logs:DeleteRetentionPolicy",
          "logs:TagResource",
          "logs:UntagResource",
          "logs:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "TerraformACMManagement"
        Effect = "Allow"
        Action = [
          "acm:RequestCertificate",
          "acm:DescribeCertificate",
          "acm:DeleteCertificate",
          "acm:AddTagsToCertificate",
          "acm:RemoveTagsFromCertificate",
          "acm:ListTagsForCertificate"
        ]
        Resource = "*"
      },
      {
        Sid    = "TerraformLoadBalancerManagement"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags",
          "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "github_actions_terraform_role_arn" {
  value = aws_iam_role.github_actions_terraform.arn
}