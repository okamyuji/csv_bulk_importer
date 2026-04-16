output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "sg_rails_web_id" {
  description = "Security group ID for Rails web containers"
  value       = aws_security_group.rails_web.id
}

output "sg_rails_worker_id" {
  description = "Security group ID for Rails worker containers"
  value       = aws_security_group.rails_worker.id
}

output "sg_rds_id" {
  description = "Security group ID for Aurora MySQL"
  value       = aws_security_group.rds.id
}

output "sg_alb_id" {
  description = "Security group ID for the ALB"
  value       = aws_security_group.alb.id
}
