#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

AWS_PROFILE="${AWS_PROFILE:-admin}"
ROLE_NAME="${ROLE_NAME:-TerraformExecutionRole}"
TRUST_POLICY="${ROOT_DIR}/policies/trust-policy.json"

echo "Creating/checking IAM role: ${ROLE_NAME}"
echo "Using AWS profile: ${AWS_PROFILE}"

if aws iam get-role \
    --role-name "$ROLE_NAME" \
    --profile "$AWS_PROFILE" \
    >/dev/null 2>&1
then
    echo "Role already exists: ${ROLE_NAME}"
else
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document "file://${TRUST_POLICY}" \
        --description "Execution role for Terraform infrastructure operations" \
        --profile "$AWS_PROFILE"

    echo "Role created successfully."
fi