output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (ALB lives here on Day 11)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (app compute + RDS live here)."
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  value = local.azs
}

output "flow_log_group" {
  description = "CloudWatch log group receiving VPC flow logs (evidence for V-CLD-08)."
  value       = aws_cloudwatch_log_group.flow.name
}
