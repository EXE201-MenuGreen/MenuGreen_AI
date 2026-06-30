# RAG AWS Deployment

This folder prepares the `RAG_AI_MenuGreen` runtime for AWS using:

- `ECR` for the container image
- `ECS Fargate` for the FastAPI runtime
- `Application Load Balancer` for ingress
- `Secrets Manager` for runtime secrets
- existing `RDS PostgreSQL` or another reachable PostgreSQL database

## What This Deploys

The CloudFormation stack in `templates/rag-ecs-fargate.yaml` creates:

- ECS cluster
- ECS task execution role and task role
- CloudWatch log group
- internet-facing ALB
- security groups
- ECS Fargate service
- optional DB security-group ingress from the service

It does **not** create the PostgreSQL database itself. Point `POSTGRES_URL` to an existing AWS RDS instance or another reachable PostgreSQL endpoint.

## ONNX Deployment Status

The AWS image packaging already includes the runtime ONNX bundle from `runtime/models`.

Included in the image by default:

- `runtime/models/intent_onnx/model.int8.onnx`
- `runtime/models/intent_onnx/label_config.json`
- `runtime/models/intent_onnx/tokenizer.json`
- related tokenizer/config files inside `runtime/models/intent_onnx`

Not included by default:

- `runtime/models/intent_onnx/model.onnx`

Runtime behavior:

- the app prefers `model.int8.onnx`
- it only falls back to `model.onnx` when the int8 file is missing

The full fp32 model is excluded by `.dockerignore` to keep the AWS image smaller. If you want the fp32 fallback model inside the deployed image too, remove this line from `.dockerignore` before building:

```bash
runtime/models/intent_onnx/model.onnx
```

## Files

- `rag-aws.env.example`: Bash-friendly environment file with the deployment inputs
- `scripts/build_and_push_ecr.sh`: builds the Docker image and pushes it to ECR
- `scripts/deploy_stack.sh`: optional one-command deploy wrapper
- `templates/rag-ecs-fargate.yaml`: ECS Fargate infrastructure template

## Prerequisites

- AWS CLI v2 configured
- Docker installed and running
- permission to use:
  - ECR
  - ECS
  - CloudFormation
  - IAM
  - ELBv2
  - EC2 security groups
  - Logs
  - Secrets Manager
- an existing VPC and subnets
- an existing PostgreSQL endpoint

## 1. Create Secrets

Create these in AWS Secrets Manager:

```bash
aws secretsmanager create-secret \
  --name menugreen/rag/postgres-url \
  --secret-string 'postgresql://user:password@host:5432/dbname'

aws secretsmanager create-secret \
  --name menugreen/rag/google-api-key \
  --secret-string 'your-google-api-key'

aws secretsmanager create-secret \
  --name menugreen/rag/google-api-keys \
  --secret-string 'key-1,key-2,key-3'

aws secretsmanager create-secret \
  --name menugreen/rag/internal-key \
  --secret-string 'replace-with-long-random-runtime-key'
```

If you only use `GOOGLE_API_KEY` or only use `GOOGLE_API_KEYS`, leave the other ARN blank in the env file.

## 2. Fill Deployment Variables

Copy the example file and update it:

```bash
cp infra/aws/rag-aws.env.example infra/aws/rag-aws.env
```

Main values to set:

- `AWS_REGION`
- `AWS_ACCOUNT_ID`
- `STACK_NAME`
- `ECR_REPO_NAME`
- `VPC_ID`
- `ALB_SUBNETS`
- `SERVICE_SUBNETS`
- `POSTGRES_URL_SECRET_ARN`
- `GOOGLE_API_KEY_SECRET_ARN` and/or `GOOGLE_API_KEYS_SECRET_ARN`
- `AI_RUNTIME_INTERNAL_KEY_SECRET_ARN`

If your database security group should only allow traffic from the ECS service, set `DB_SECURITY_GROUP_ID`.

## 3. Build, Push, and Deploy

```bash
source infra/aws/rag-aws.env
bash infra/aws/scripts/deploy_stack.sh
```

The deploy script will:

1. create the ECR repository if missing
2. build the image from the repository root
3. push the image to ECR
4. deploy or update the CloudFormation stack
5. print the resulting stack outputs

## 4. Verify

Check the ALB DNS output and call:

```bash
curl http://<alb-dns-name>/health
```

Expected response:

```json
{"status":"ok","service":"runtime"}
```

If `SERVE_FRONTEND=true`, `/` will also serve the runtime test frontend.

## Notes

- The Docker image uses the repository root `Dockerfile` that already packages only the runtime artifacts.
- The `.env` file is intentionally excluded from the image. AWS secrets are injected at runtime.
- The ONNX runtime bundle must exist locally before `docker build`, especially:
  - `runtime/models/intent_onnx/model.int8.onnx`
  - `runtime/models/intent_onnx/label_config.json`
  - `runtime/models/intent_onnx/tokenizer.json`
- If the service runs in private subnets without NAT, image pulls and external API calls will fail. In that case either:
  - use public subnets with `ASSIGN_PUBLIC_IP=ENABLED`, or
  - provide NAT/VPC endpoints and set `ASSIGN_PUBLIC_IP=DISABLED`
