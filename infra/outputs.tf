output "ecr_repository_url" {
  description = "ECR repository URL — use this as the base for image tags."
  value       = aws_ecr_repository.this.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "deploy_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC — set as AWS_DEPLOY_ROLE_ARN secret in GitHub."
  value       = aws_iam_role.deploy.arn
}
