#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

AWS_REGION="${AWS_REGION:-}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"
ECR_REPO_NAME="${ECR_REPO_NAME:-menugreen-rag-runtime}"
IMAGE_TAG="${IMAGE_TAG:-$(date +%Y%m%d%H%M%S)}"

command -v aws >/dev/null 2>&1 || {
  echo "AWS CLI is required but was not found in PATH." >&2
  exit 1
}

command -v docker >/dev/null 2>&1 || {
  echo "Docker is required but was not found in PATH." >&2
  exit 1
}

if [[ -z "${AWS_REGION}" || -z "${AWS_ACCOUNT_ID}" ]]; then
  echo "AWS_REGION and AWS_ACCOUNT_ID must be set." >&2
  exit 1
fi

IMAGE_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG}"

if ! aws ecr describe-repositories --region "${AWS_REGION}" --repository-names "${ECR_REPO_NAME}" >/dev/null 2>&1; then
  aws ecr create-repository \
    --region "${AWS_REGION}" \
    --repository-name "${ECR_REPO_NAME}" \
    --image-scanning-configuration scanOnPush=true \
    >/dev/null
fi

aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

docker build -t "${ECR_REPO_NAME}:${IMAGE_TAG}" "${REPO_ROOT}"
docker tag "${ECR_REPO_NAME}:${IMAGE_TAG}" "${IMAGE_URI}"
docker push "${IMAGE_URI}"

echo "${IMAGE_URI}"
