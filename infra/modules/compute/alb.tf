# =====================================================================
# Application Load Balancer — the single internet entry point (Layer 7).
# Lives in PUBLIC subnets; forwards to tasks in PRIVATE subnets.
# Path routing: /payments/* -> payments service, /kyc/* -> kyc service.
# =====================================================================

resource "aws_lb" "main" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  drop_invalid_header_fields = true
  enable_deletion_protection = false # dev

  tags = { Name = "${var.name_prefix}-alb" }
}

# Target groups: one per service. target_type=ip because Fargate tasks
# register by IP, not by instance.
resource "aws_lb_target_group" "payments" {
  name        = "${var.name_prefix}-payments-tg"
  port        = var.payments_container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
  tags = { Name = "${var.name_prefix}-payments-tg" }
}

resource "aws_lb_target_group" "kyc" {
  name        = "${var.name_prefix}-kyc-tg"
  port        = var.kyc_container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
  tags = { Name = "${var.name_prefix}-kyc-tg" }
}

# HTTP listener. For dev we serve on :80 directly (no ACM cert/domain).
# Default action -> payments; path rules below split the traffic.
# NOTE: production would add a 443 listener with an ACM certificate and
# redirect 80->443. Documented in the ADR.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.payments.arn
  }
}

resource "aws_lb_listener_rule" "payments" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.payments.arn
  }
  condition {
    path_pattern { values = ["/payments/*", "/v1/payments/*"] }
  }
}

resource "aws_lb_listener_rule" "kyc" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kyc.arn
  }
  condition {
    path_pattern { values = ["/kyc/*", "/v1/kyc/*"] }
  }
}
