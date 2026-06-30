# RAG AWS Deploy Prep Report

## Scope

This report covers only `D:\EXE\RAG_AI_MenuGreen`.

`MenuGreenSystem` is intentionally out of scope because the System side is being deployed by another person.

## What Was Prepared

- Added AWS deployment guide: `infra/aws/README.md`
- Added deploy environment template: `infra/aws/rag-aws.env.example`
- Added ECR build and push script: `infra/aws/scripts/build_and_push_ecr.sh`
- Added one-command deploy wrapper: `infra/aws/scripts/deploy_stack.sh`
- Added ECS Fargate CloudFormation template: `infra/aws/templates/rag-ecs-fargate.yaml`

## Target Architecture

- Docker image built from the existing repository `Dockerfile`
- Image stored in `Amazon ECR`
- Runtime deployed on `Amazon ECS Fargate`
- Public ingress through `Application Load Balancer`
- Runtime secrets loaded from `AWS Secrets Manager`
- PostgreSQL kept external or on existing AWS RDS
- Optional frontend served by the same FastAPI runtime when `SERVE_FRONTEND=true`

## ONNX Packaging Result

The deployment is prepared to ship the ONNX runtime bundle together with the container image.

### Included by default

- `runtime/models/intent_onnx/model.int8.onnx`
- `runtime/models/intent_onnx/label_config.json`
- `runtime/models/intent_onnx/tokenizer.json`
- other tokenizer/config assets inside `runtime/models/intent_onnx`

### Excluded by default

- `runtime/models/intent_onnx/model.onnx`

Reason: `.dockerignore` excludes the larger fp32 file to reduce image size and deploy time. The current AWS deploy path is therefore based on the quantized ONNX model bundle.

Runtime behavior:

- `runtime/app/core/onnx_intent.py` prefers `model.int8.onnx`
- it falls back to `model.onnx` only if the int8 file is not present

## Deploy Coverage

### Included

- ECS cluster
- ECS service
- ECS task definition
- CloudWatch log group
- ALB
- security groups
- optional DB ingress rule from ECS service SG to PostgreSQL SG
- secret injection for:
  - `POSTGRES_URL`
  - `GOOGLE_API_KEY`
  - `GOOGLE_API_KEYS`
  - `AI_RUNTIME_INTERNAL_KEY`

### Not Included

- RDS creation
- Route53 DNS
- ACM certificate issuance
- WAF
- CI/CD pipeline
- autoscaling policies
- Prometheus/Grafana

## Hardening Done

- Removed explicit ALB and Target Group names to reduce AWS name-length and collision risk
- Added `HealthCheckGracePeriodSeconds=60` for ECS service startup
- Added AWS CLI presence checks in deploy scripts
- Added Docker presence check in image build script

## Validation Performed

- `bash -n infra/aws/scripts/build_and_push_ecr.sh`
- `bash -n infra/aws/scripts/deploy_stack.sh`
- Reviewed runtime Dockerfile compatibility with ECS deployment
- Reviewed runtime config fields required by AWS secret injection
- Verified local model bundle exists in `runtime/models/intent_onnx`

## Validation Not Performed Here

- Live `aws cloudformation validate-template`
- Live stack deployment
- Live ECR push
- Live ECS task startup
- Live Docker image build with the ONNX bundle

Reason: current machine session does not have AWS CLI available for execution in this workspace flow, and Docker Desktop service is stopped, so live AWS commands and live image build could not be run here.

## Deploy Command Flow

```bash
cd /d/EXE/RAG_AI_MenuGreen
cp infra/aws/rag-aws.env.example infra/aws/rag-aws.env
source infra/aws/rag-aws.env
bash infra/aws/scripts/deploy_stack.sh
```

## Required Secrets

- `POSTGRES_URL_SECRET_ARN`
- at least one of:
  - `GOOGLE_API_KEY_SECRET_ARN`
  - `GOOGLE_API_KEYS_SECRET_ARN`
- optional:
  - `AI_RUNTIME_INTERNAL_KEY_SECRET_ARN`

## Important Assumptions

- Existing VPC and subnets are already available
- Existing PostgreSQL is reachable from the ECS service
- Docker build context already contains:
  - `runtime/models/intent_onnx/model.int8.onnx`
  - `runtime/models/intent_onnx/label_config.json`
  - `runtime/models/intent_onnx/tokenizer.json`
- If using private subnets, NAT or VPC endpoints must exist for image pulls and outbound API calls

## Recommended Next Step

Run the deploy flow from a machine that has:

- AWS CLI v2
- Docker
- valid AWS credentials for the target account

After deployment, verify:

```bash
curl http://<alb-dns>/health
```

or:

```bash
curl https://<alb-dns>/health
```

depending on whether ACM HTTPS is enabled.
