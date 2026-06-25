variable "name" {
  description = "Name prefix applied to all resources."
  type        = string
  default     = "ecs-deploy-pipeline"
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-1"
}

variable "vpc_id" {
  description = "ID of the VPC where the ECS service will run."
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ECS service. Use public subnets if no NAT Gateway is available."
  type        = list(string)
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach the container port."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
  default     = 8080
}

variable "container_image" {
  description = "Full ECR image URI to deploy (e.g. 123456789.dkr.ecr.eu-west-1.amazonaws.com/ecs-deploy-pipeline:abc1234)."
  type        = string
  default     = "public.ecr.aws/amazonlinux/amazonlinux:latest"
}

variable "task_cpu" {
  description = "Fargate task CPU units (256, 512, 1024, 2048, 4096)."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of running task replicas."
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days."
  type        = number
  default     = 365
}

variable "github_org" {
  description = "GitHub organisation or username that owns this repo (used for OIDC trust policy)."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (used for OIDC trust policy)."
  type        = string
  default     = "ecs-deploy-pipeline"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
