#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

AWS_PROFILE="${AWS_PROFILE:-admin}"

ACCOUNT_ID="$(aws sts get-caller-identity \
    --profile "$AWS_PROFILE" \
    --query Account \
    --output text)"

create_policy() {
    local policy_name="$1"
    local policy_file="$2"
    local policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/${policy_name}"

    echo
    echo "Checking policy: ${policy_name}"

    if aws iam get-policy \
        --policy-arn "$policy_arn" \
        --profile "$AWS_PROFILE" \
        >/dev/null 2>&1
    then
        echo "Policy already exists: ${policy_name}"
    else
        aws iam create-policy \
            --policy-name "$policy_name" \
            --policy-document "file://${ROOT_DIR}/${policy_file}" \
            --profile "$AWS_PROFILE"

        echo "Policy created: ${policy_name}"
    fi
}

create_policy \
    "TerraformNetworkingPolicy" \
    "policies/terraform-networking-policy.json"

create_policy \
    "TerraformComputePolicy" \
    "policies/terraform-compute-policy.json"

echo
echo "Policy creation/check completed."