# ── ECR repository ────────────────────────────────────────────────────────────

resource "aws_ecr_repository" "this" {
  # checkov:skip=CKV_AWS_136:AWS-managed key encryption acceptable for this use case
  name                 = var.name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images, expire older ones"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# ── CloudWatch log group ──────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "ecs" {
  # checkov:skip=CKV_AWS_158:AWS-managed key encryption acceptable for this use case
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# ── ECS cluster ───────────────────────────────────────────────────────────────

resource "aws_ecs_cluster" "this" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# ── IAM task execution role ───────────────────────────────────────────────────

resource "aws_iam_role" "task_execution" {
  name = "${var.name}-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ── Security group ────────────────────────────────────────────────────────────

resource "aws_security_group" "ecs_tasks" {
  # checkov:skip=CKV_AWS_25:Egress required for ECR image pull and CloudWatch Logs
  # checkov:skip=CKV_AWS_382:Egress required for ECR image pull and CloudWatch Logs
  # checkov:skip=CKV2_AWS_5:SG is attached to ECS service via network_configuration
  name        = "${var.name}-ecs-tasks"
  description = "Allow inbound on container port; allow all outbound for AWS API calls"
  vpc_id      = var.vpc_id

  ingress {
    description = "Container port"
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr_blocks
  }

  egress {
    description = "All outbound - required to pull ECR images and write CloudWatch logs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-ecs-tasks" })
}

# ── ECS task definition ───────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([{
    name      = var.name
    image     = var.container_image
    essential = true
    user      = "appuser"

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    environment = [
      { name = "PORT", value = tostring(var.container_port) }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }

    readonlyRootFilesystem = true

    healthCheck = {
      command     = ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:8080/health')\" || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }
  }])

  tags = var.tags
}

# ── ECS service ───────────────────────────────────────────────────────────────

resource "aws_ecs_service" "this" {
  # checkov:skip=CKV_AWS_97:Public IP required in public subnets without NAT Gateway
  # checkov:skip=CKV_AWS_333:Public IP required in public subnets without NAT Gateway
  name            = var.name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = var.tags
}
