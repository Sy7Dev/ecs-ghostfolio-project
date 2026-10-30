output "ecr_repository_url" {
  description = "ECR repository URL for the Ghostfolio image"
  value       = aws_ecr_repository.ghostfolio.repository_url
}

output "alb_dns_name" {
  description = "Public DNS name of the load balancer"
  value       = module.load_balancer.alb_dns_name
}

output "ghostfolio_url" {
  description = "HTTP URL for the Ghostfolio demo"
  value       = "https://${var.domain_name}"
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "certificate_validation_records" {
  description = "DNS records required to validate the ACM certificate"
  value       = module.load_balancer.certificate_validation_records
}

output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = module.load_balancer.certificate_arn
}
