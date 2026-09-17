# Terraform AWS IAM Role Testing

## 1. Purpose

This document describes the tests used to verify the Terraform AWS IAM execution architecture.

Testing is performed using the `terraform` AWS CLI profile because this profile represents the identity Terraform will use when interacting with AWS.

The tests verify two categories of behavior:

1. Operations Terraform is expected to perform are allowed.
2. Operations outside Terraform's intended permission scope are denied.

---

# 2. Testing Principle

A permission test must be evaluated according to the expected behavior of the operation.

For an authorized operation:

```text
Request succeeds
        ↓
Expected behavior
        ↓
PASS
```

For an unauthorized operation:

```text
Request denied
        ↓
Expected security behavior
        ↓
PASS
```

Therefore, `AccessDenied` does not automatically represent a failed test.

The expected result depends on the permission being tested.

---

# 3. Test Profile

The tests use:

```text
AWS CLI profile:
terraform
```

The profile is configured to assume:

```text
TerraformExecutionRole
```

The administrative `admin` profile is not used for testing the Terraform permission boundary because testing with the administrative profile would not demonstrate what Terraform itself is permitted to do.

---

# 4. Identity Test

## Command

```bash
aws sts get-caller-identity --profile terraform
```

## Purpose

This verifies the effective AWS identity being used by the `terraform` profile.

## Expected Result

The returned ARN should identify an assumed role similar to:

```text
arn:aws:sts::035680193151:assumed-role/TerraformExecutionRole/<session-name>
```

The result should not identify the Terraform session as:

```text
arn:aws:iam::035680193151:user/Martins
```

## Interpretation

A successful assumed-role identity confirms that the AWS CLI profile is using the intended execution role.

---

# 5. Networking Permission Tests

The Terraform role is expected to have networking permissions.

## VPC Test

```bash
aws ec2 describe-vpcs --profile terraform
```

Expected result:

```text
PASS
```

The command should return the VPC information available to the role.

---

## Subnet Test

```bash
aws ec2 describe-subnets --profile terraform
```

Expected result:

```text
PASS
```

---

## Security Group Test

```bash
aws ec2 describe-security-groups --profile terraform
```

Expected result:

```text
PASS
```

---

# 6. Compute Permission Test

The Terraform role is expected to have compute read permissions.

## Command

```bash
aws ec2 describe-instances --profile terraform
```

Expected result:

```text
PASS
```

The command should successfully return EC2 instance information available to the role.

---

# 7. Unauthorized IAM Test

The Terraform role is not intended to administer IAM.

## Command

```bash
aws iam list-users --profile terraform
```

## Expected Result

The request should fail with an authorization error such as:

```text
AccessDenied
```

## Interpretation

This is a successful security test.

The test demonstrates that the Terraform execution role does not have permission to list IAM users.

The fact that the administrative source identity can perform IAM operations does not mean the assumed Terraform role can perform them.

---

# 8. Cost Management Test

Cost-management functionality is outside the current Terraform execution scope.

A Cost Explorer operation was tested using the Terraform profile.

The operation was denied.

Expected result:

```text
AccessDenied
```

This is interpreted as a successful negative authorization test.

The Terraform role is therefore not being used as a billing or cost-management identity.

---

# 9. Test Categories

The tests can be grouped into:

```text
Identity
│
└── Verify assumed role

Networking
│
├── Describe VPCs
├── Describe Subnets
└── Describe Security Groups

Compute
│
└── Describe Instances

Unauthorized
│
├── IAM Users
└── Cost Management
```

This provides evidence that the role behaves differently depending on whether an operation belongs to its intended permission scope.

---

# 10. Expected Test Matrix

| Test                           | Expected Result | Security Meaning                    |
| ------------------------------ | --------------- | ----------------------------------- |
| `sts get-caller-identity`      | Allowed         | Confirms assumed-role identity      |
| `ec2 describe-vpcs`            | Allowed         | Networking read access works        |
| `ec2 describe-subnets`         | Allowed         | Networking read access works        |
| `ec2 describe-security-groups` | Allowed         | Security-group read access works    |
| `ec2 describe-instances`       | Allowed         | Compute read access works           |
| `iam list-users`               | Denied          | IAM administration is outside scope |
| Cost Explorer operation        | Denied          | Cost management is outside scope    |

---

# 11. Positive and Negative Testing

The testing strategy deliberately includes both successful and unsuccessful authorization attempts.

Positive tests establish that the role has enough permission to perform its intended infrastructure responsibilities.

Negative tests establish that the role does not have unrelated privileges.

Testing only successful operations would not provide enough evidence for a least-privilege design.

For example:

```text
"Terraform can describe EC2 instances"
```

proves that one required capability works.

But:

```text
"Terraform cannot list IAM users"
```

provides evidence that the role does not have unrestricted AWS access.

Both observations are important.

---

# 12. Security Test Interpretation

The tests should not be interpreted as a general proof that the IAM architecture is perfectly secure.

They establish that the tested operations behaved according to the intended V1 permission model.

A complete security review would require examining:

* All attached policies
* Policy versions
* Trust relationships
* Resource policies where applicable
* Account-level controls
* Organization-level controls where applicable
* Permissions boundaries where applicable
* Service control policies where applicable
* Resource-level restrictions
* Credential management

The current test suite is therefore evidence for the implemented V1 design rather than a universal security certification.

---

# 13. Reproducible Test Script

The repository contains:

```text
scripts/test-permissions.sh
```

This script automates the primary permission checks.

The script tests:

1. Effective identity
2. Networking access
3. Compute access
4. Unauthorized IAM access

The script treats unexpected authorization behavior as a test failure.

For example:

```text
Required permission denied
        ↓
FAIL
```

while:

```text
Unauthorized permission denied
        ↓
PASS
```

---

# 14. Verification Workflow

The recommended verification sequence is:

```text
1. Verify role
       ↓
2. Verify effective identity
       ↓
3. Test required networking permissions
       ↓
4. Test required compute permissions
       ↓
5. Test unauthorized IAM access
       ↓
6. Test cost-management restriction
       ↓
7. Record results
```

This ensures that identity configuration is verified before permission behavior is evaluated.

---

# 15. Current Test Result

The V1 implementation was tested using the `terraform` profile.

The observed results were consistent with the intended permission model:

```text
Role assumption              PASS
Networking permissions       PASS
Compute permissions          PASS
IAM restriction              PASS
Cost-management restriction  PASS
```

For the negative tests, `AccessDenied` was the expected and successful result.

---

# 16. Future Testing

As additional policies are introduced, the test suite should expand with them.

For example, if an RDS policy is added:

```text
RDS operation expected to succeed
        ↓
Positive test
```

If S3 is added:

```text
S3 operation expected to succeed
        ↓
Positive test
```

The test suite should also retain negative tests for services that remain outside Terraform's scope.

This keeps the security boundary testable as the role evolves.

---

# 17. Testing Philosophy

The purpose of the test suite is not simply to prove that commands work.

It is to verify that the IAM role behaves according to its intended authorization boundary.

The central question is:

> Can Terraform perform what it needs to perform, while remaining unable to perform what it does not need to perform?

The V1 tests provide evidence for that distinction across identity, networking, compute, IAM, and cost-management operations.
