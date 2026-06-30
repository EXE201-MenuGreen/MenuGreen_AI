#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
TEMPLATE_PATH="${REPO_ROOT}/infra/aws/templates/rag-ecs-fargate.yaml"

command -v aws >/dev/null 2>&1 || {
  echo "AWS CLI is required but was not found in PATH." >&2
  exit 1
}

required_vars=(
  AWS_REGION
  AWS_ACCOUNT_ID
  STACK_NAME
  PROJECT_NAME
  ENVIRONMENT_NAME
  VPC_ID
  ALB_SUBNETS
  SERVICE_SUBNETS
  POSTGRES_URL_SECRET_ARN
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "Missing required environment variable: ${var_name}" >&2
    exit 1
  fi
done

IMAGE_URI="${IMAGE_URI:-}"
if [[ -z "${IMAGE_URI}" ]]; then
  IMAGE_URI="$(bash "${SCRIPT_DIR}/build_and_push_ecr.sh")"
fi

DESIRED_COUNT="${DESIRED_COUNT:-1}"
TASK_CPU="${TASK_CPU:-1024}"
TASK_MEMORY="${TASK_MEMORY:-2048}"
CONTAINER_PORT="${CONTAINER_PORT:-8000}"
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-14}"
HEALTH_CHECK_PATH="${HEALTH_CHECK_PATH:-/health}"
ASSIGN_PUBLIC_IP="${ASSIGN_PUBLIC_IP:-ENABLED}"
ALLOWED_INGRESS_CIDR="${ALLOWED_INGRESS_CIDR:-0.0.0.0/0}"
DB_SECURITY_GROUP_ID="${DB_SECURITY_GROUP_ID:-}"
ACM_CERTIFICATE_ARN="${ACM_CERTIFICATE_ARN:-}"
GOOGLE_API_KEY_SECRET_ARN="${GOOGLE_API_KEY_SECRET_ARN:-}"
GOOGLE_API_KEYS_SECRET_ARN="${GOOGLE_API_KEYS_SECRET_ARN:-}"
AI_RUNTIME_INTERNAL_KEY_SECRET_ARN="${AI_RUNTIME_INTERNAL_KEY_SECRET_ARN:-}"
DEBUG="${DEBUG:-false}"
SERVE_FRONTEND="${SERVE_FRONTEND:-false}"
INTENT_MODEL_DIR="${INTENT_MODEL_DIR:-models/intent_onnx}"
GEMINI_QUERY_REWRITE_ENABLED="${GEMINI_QUERY_REWRITE_ENABLED:-true}"
GEMINI_RESPONSE_FALLBACK_ENABLED="${GEMINI_RESPONSE_FALLBACK_ENABLED:-true}"

aws cloudformation deploy \
  --region "${AWS_REGION}" \
  --stack-name "${STACK_NAME}" \
  --template-file "${TEMPLATE_PATH}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    ProjectName="${PROJECT_NAME}" \
    EnvironmentName="${ENVIRONMENT_NAME}" \
    VpcId="${VPC_ID}" \
    AlbSubnetIds="${ALB_SUBNETS}" \
    ServiceSubnetIds="${SERVICE_SUBNETS}" \
    AssignPublicIp="${ASSIGN_PUBLIC_IP}" \
    DbSecurityGroupId="${DB_SECURITY_GROUP_ID}" \
    AllowedIngressCidr="${ALLOWED_INGRESS_CIDR}" \
    ContainerImage="${IMAGE_URI}" \
    ContainerPort="${CONTAINER_PORT}" \
    DesiredCount="${DESIRED_COUNT}" \
    TaskCpu="${TASK_CPU}" \
    TaskMemory="${TASK_MEMORY}" \
    LogRetentionDays="${LOG_RETENTION_DAYS}" \
    HealthCheckPath="${HEALTH_CHECK_PATH}" \
    AcmCertificateArn="${ACM_CERTIFICATE_ARN}" \
    PostgresUrlSecretArn="${POSTGRES_URL_SECRET_ARN}" \
    GoogleApiKeySecretArn="${GOOGLE_API_KEY_SECRET_ARN}" \
    GoogleApiKeysSecretArn="${GOOGLE_API_KEYS_SECRET_ARN}" \
    AiRuntimeInternalKeySecretArn="${AI_RUNTIME_INTERNAL_KEY_SECRET_ARN}" \
    Debug="${DEBUG}" \
    ServeFrontend="${SERVE_FRONTEND}" \
    IntentModelDir="${INTENT_MODEL_DIR}" \
    GeminiQueryRewriteEnabled="${GEMINI_QUERY_REWRITE_ENABLED}" \
    GeminiResponseFallbackEnabled="${GEMINI_RESPONSE_FALLBACK_ENABLED}"

aws cloudformation describe-stacks \
  --region "${AWS_REGION}" \
  --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs" \
  --output table
