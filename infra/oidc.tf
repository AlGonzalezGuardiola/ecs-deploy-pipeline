# GitHub Actions OIDC — keyless authentication (no long-lived AWS keys needed)

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = var.tags
}

resource "aws_iam_role" "deploy" {
  name = "${var.name}-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "deploy" {
  # checkov:skip=CKV_AWS_355:ECR GetAuthorizationToken, ECS Describe and RegisterTaskDefinition do not support resource-level permissions
  name = "${var.name}-deploy"
  role = aws_iam_role.deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        # GetAuthorizationToken doesn't support resource-level permissions
        Resource = ["*"]
      },
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
        ]
        Resource = [aws_ecr_repository.this.arn]
      },
      {
        Sid    = "ECSDescribe"
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeServices",
        ]
        Resource = ["*"]
      },
      {
        Sid      = "ECSDeployTaskDef"
        Effect   = "Allow"
        Action   = ["ecs:RegisterTaskDefinition"]
        Resource = ["*"]
      },
      {
        Sid      = "ECSUpdateService"
        Effect   = "Allow"
        Action   = ["ecs:UpdateService"]
        Resource = [aws_ecs_service.this.id]
      },
      {
        Sid      = "IAMPassRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = [aws_iam_role.task_execution.arn]
      },
    ]
  })
}
