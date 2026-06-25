# =====================================================================
# The security-group CHAIN: internet -> ALB -> app -> (database).
# Each hop is gated by SG REFERENCE, not CIDR. This is the core of the
# "no compute internet-addressable" + "DB ingress by reference" design.
# =====================================================================

locals {
  # The app SG must accept each container port from the ALB. payments and kyc
  # MAY share a port (e.g. both 80 with placeholder images) or differ (8001 /
  # 8002 with real images). toset() collapses duplicates so we never try to
  # create the same ingress rule twice.
  app_ingress_ports = toset([
    tostring(var.payments_container_port),
    tostring(var.kyc_container_port),
  ])
}

# 1) ALB SG: the only thing allowed to face the internet.
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Public entry point. Internet to ALB on 80 and 443 only."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP from internet (redirected to HTTPS at the listener)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "To app tasks"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.name_prefix}-alb-sg" }
}

# 2) App SG: tasks accept traffic ONLY from the ALB SG (by reference).
resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app-sg"
  description = "Fargate tasks. Ingress only from the ALB security group."
  vpc_id      = var.vpc_id

  egress {
    description = "All outbound (reach DB, Secrets Manager, ECR, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.name_prefix}-app-sg" }
}

# Ingress to app from ALB only, ONE rule per UNIQUE container port.
# (Brief: ingress by SG reference, not CIDR.)
resource "aws_security_group_rule" "app_from_alb" {
  for_each                 = local.app_ingress_ports
  type                     = "ingress"
  from_port                = tonumber(each.value)
  to_port                  = tonumber(each.value)
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.alb.id
  description              = "app port ${each.value} from ALB"
}
