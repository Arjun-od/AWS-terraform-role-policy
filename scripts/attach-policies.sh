#!/usr/bin/env bash

set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-admin}"
ROLE_NAME="${ROLE_NAME:-TerraformExecutionRole}"

ACCOUNT_ID="$(aws sts get-caller-identity \
    --profile "$AWS_PROFILE" \
    --query Account \
    --output text)"

POLICIES=(
    "TerraformNetworkingPolicy"
    "TerraformComputePolicy"
)

for POLICY_NAME in "${POLICIES[@]}"; do

    POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

    echo
    echo "Attaching ${POLICY_NAME} to ${ROLE_NAME}..."

    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "$POLICY_ARN" \
        --profile "$AWS_PROFILE"

    echo "Attached: ${POLICY_NAME}"

done

echo
echo "Policy attachment completed."