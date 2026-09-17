#!/usr/bin/env bash

set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-admin}"
TF_PROFILE="${TF_PROFILE:-terraform}"
ROLE_NAME="${ROLE_NAME:-TerraformExecutionRole}"

echo "======================================"
echo "Terraform IAM Role Verification"
echo "======================================"

echo
echo "1. Role information"
aws iam get-role \
    --role-name "$ROLE_NAME" \
    --profile "$AWS_PROFILE"

echo
echo "2. Attached policies"
aws iam list-attached-role-policies \
    --role-name "$ROLE_NAME" \
    --profile "$AWS_PROFILE"

echo
echo "3. Terraform effective identity"
aws sts get-caller-identity \
    --profile "$TF_PROFILE"

echo
echo "Verification completed."