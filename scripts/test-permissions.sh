#!/usr/bin/env bash

set -euo pipefail

TF_PROFILE="${TF_PROFILE:-terraform}"

echo "======================================"
echo "Terraform Role Permission Tests"
echo "======================================"

echo
echo "1. Testing effective identity"
aws sts get-caller-identity \
    --profile "$TF_PROFILE"

echo
echo "2. Testing networking permissions"
aws ec2 describe-vpcs \
    --profile "$TF_PROFILE" \
    >/dev/null

aws ec2 describe-subnets \
    --profile "$TF_PROFILE" \
    >/dev/null

aws ec2 describe-security-groups \
    --profile "$TF_PROFILE" \
    >/dev/null

echo "PASS: Networking permissions are available."

echo
echo "3. Testing compute permissions"
aws ec2 describe-instances \
    --profile "$TF_PROFILE" \
    >/dev/null

echo "PASS: Compute permissions are available."

echo
echo "4. Testing unauthorized IAM access"

if aws iam list-users \
    --profile "$TF_PROFILE" \
    >/dev/null 2>&1
then
    echo "FAIL: IAM access was unexpectedly allowed."
    exit 1
else
    echo "PASS: IAM access was denied as expected."
fi

echo
echo "======================================"
echo "All permission tests passed."
echo "======================================"