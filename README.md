# ecs-deploy-pipeline

End-to-end CI/CD pipeline that builds a Docker image, scans it with Trivy, pushes it to Amazon ECR and deploys it to ECS Fargate — using GitHub Actions OIDC (no long-lived AWS keys).

## Pipeline

```
Pull Request                          Push to main
──────────────                        ────────────────────────────────────
terraform fmt                         OIDC → assume AWS deploy role
terraform validate                    docker build + push → ECR
tflint                                register new ECS task definition
checkov                               aws ecs update-service
docker build
trivy scan (CRITICAL/HIGH, exit 1)
```

## Infrastructure (Terraform)

```
infra/
├── main.tf    — ECR, ECS cluster + service (Fargate), IAM, CloudWatch
├── oidc.tf    — GitHub Actions OIDC provider + least-privilege deploy role
├── variables.tf
├── outputs.tf
└── versions.tf
```

## Deployment

```bash
cd infra

cat > terraform.tfvars <<EOF
vpc_id     = "vpc-xxxxxxxx"
subnet_ids = ["subnet-aaa", "subnet-bbb"]
github_org = "AlGonzalezGuardiola"
EOF

terraform init
terraform apply
```

After apply, set the `deploy_role_arn` output as `AWS_DEPLOY_ROLE_ARN` in GitHub repository secrets.

## Configuration

| Variable | Description | Default |
|---|---|---|
| `vpc_id` | VPC to deploy into | required |
| `subnet_ids` | Subnets for ECS tasks | required |
| `github_org` | GitHub org/user for OIDC trust | required |
| `container_port` | Port the app listens on | `8080` |
| `task_cpu` | Fargate CPU units | `256` |
| `task_memory` | Fargate memory (MiB) | `512` |
| `desired_count` | Running task replicas | `1` |

## App

Minimal Python HTTP server (no dependencies) with two endpoints:

| Endpoint | Response |
|---|---|
| `GET /` | `{"service": "ecs-deploy-pipeline", "version": "...", "python": "..."}` |
| `GET /health` | `{"status": "ok"}` |

## Security

- **OIDC authentication** — GitHub Actions assumes an IAM role via web identity. No long-lived access keys stored as secrets.
- **Least-privilege IAM** — deploy role can only push to the specific ECR repo and update the specific ECS service.
- **Non-root container** — runs as `appuser`, read-only root filesystem.
- **Trivy scan** — blocks on CRITICAL or HIGH unfixed CVEs.
- **ECR** — tag immutability enabled, scan on push enabled, lifecycle policy retains last 10 images.

## License

MIT
