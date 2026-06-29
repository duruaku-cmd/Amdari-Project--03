# =====================================================================
# ECS Fargate cluster + two services (payments, kyc), each on its OWN
# task role (V-CLD-05 intact), in PRIVATE subnets with no public IP.
# =====================================================================

resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = { Name = "${var.name_prefix}-cluster" }
}

# CloudWatch log groups for each service.
resource "aws_cloudwatch_log_group" "payments" {
  name              = "/ecs/${var.name_prefix}/payments"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "kyc" {
  name              = "/ecs/${var.name_prefix}/kyc"
  retention_in_days = 14
}

data "aws_region" "current" {}

# ---- payments task definition ----
resource "aws_ecs_task_definition" "payments" {
  family                   = "${var.name_prefix}-payments"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.payments_exec_role_arn
  task_role_arn            = var.payments_task_role_arn

  container_definitions = jsonencode([
    {
      name         = "payments-api"
      image        = var.payments_image
      essential    = true
      portMappings = [{ containerPort = var.payments_container_port, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.payments.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "payments"
        }
      }
    }
  ])
  tags = { Service = "payments-api" }
}

# ---- kyc task definition ----
resource "aws_ecs_task_definition" "kyc" {
  family                   = "${var.name_prefix}-kyc"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.kyc_exec_role_arn
  task_role_arn            = var.kyc_task_role_arn

  container_definitions = jsonencode([
    {
      name         = "kyc-api"
      image        = var.kyc_image
      essential    = true
      portMappings = [{ containerPort = var.kyc_container_port, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.kyc.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "kyc"
        }
      }
    }
  ])
  tags = { Service = "kyc-api" }
}

# ---- payments service ----
resource "aws_ecs_service" "payments" {
  name            = "${var.name_prefix}-payments"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.payments.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids # PRIVATE: no public exposure
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.payments.arn
    container_name   = "payments-api"
    container_port   = var.payments_container_port
  }

  depends_on = [aws_lb_listener.http]
  tags       = { Service = "payments-api" }
}

# ---- kyc service ----
resource "aws_ecs_service" "kyc" {
  name            = "${var.name_prefix}-kyc"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.kyc.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.kyc.arn
    container_name   = "kyc-api"
    container_port   = var.kyc_container_port
  }

  depends_on = [aws_lb_listener.http]
  tags       = { Service = "kyc-api" }
}
