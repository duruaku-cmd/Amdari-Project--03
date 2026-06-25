output "alb_dns_name" {
  description = "Public URL of the load balancer (the only internet entry point)."
  value       = aws_lb.main.dns_name
}

output "app_security_group_id" {
  description = "App SG. The data module references this for RDS ingress-by-reference."
  value       = aws_security_group.app.id
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "waf_acl_arn" {
  description = "WAF web ACL protecting the ALB."
  value       = aws_wafv2_web_acl.main.arn
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}
