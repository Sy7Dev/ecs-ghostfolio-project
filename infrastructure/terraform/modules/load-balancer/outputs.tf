output "alb_dns_name" {
  description = "Public DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "ARN of the Ghostfolio target group"
  value       = aws_lb_target_group.ghostfolio.arn
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "certificate_validation_records" {
  description = "DNS records required to validate the ACM certificate"
  value       = aws_acm_certificate.ghostfolio.domain_validation_options
}

output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.ghostfolio.arn
}
