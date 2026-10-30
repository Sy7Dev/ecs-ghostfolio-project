output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "availability_zones" {
  description = "Availability zones used by the public subnets"
  value       = var.availability_zones
}
