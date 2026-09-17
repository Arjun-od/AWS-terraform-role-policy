#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage:"
    echo "./scripts/update-policy-version.sh <policy-name> <policy-file>"
    exit 1
fi

POLICY_NAME="$1"
POLICY_FILE="$2"

AWS_PROFILE="${AWS_PROFILE:-admin}"

ACCOUNT_ID="$(aws sts get-caller-identity \
    --profile "$AWS_PROFILE" \
    --query Account \
    --output text)"

POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

if [[ ! -f "$POLICY_FILE" ]]; then
    echo "Policy file not found: ${POLICY_FILE}"
    exit 1
fi

echo "Creating new policy version for:"
echo "${POLICY_NAME}"

aws iam create-policy-version \
    --policy-arn "$POLICY_ARN" \
    --policy-document "file://${POLICY_FILE}" \
    --set-as-default \
    --profile "$AWS_PROFILE"

echo
echo "New policy version created and set as default."