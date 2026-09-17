# Terraform AWS Least-Privilege IAM Role

## Project Overview

This project implements a controlled AWS IAM architecture for Terraform.

The objective is to allow Terraform to provision and manage AWS infrastructure through an IAM role with a deliberately limited set of permissions, rather than giving Terraform permanent credentials belonging to an IAM user.

The architecture separates:

* The identity used to initiate the role assumption
* The IAM role Terraform operates as
* The trust policy that controls who can assume the role
* The permission policies that control what the role can do
* Temporary credentials issued through AWS STS
* The AWS infrastructure Terraform is permitted to manage

The project is designed around the principle of **least privilege** and is intended to evolve as infrastructure requirements change.

---

# 1. Project Objective

The primary objective is to create an IAM role that Terraform can use to provision and manage AWS infrastructure without giving Terraform permanent IAM-user credentials.

The design intentionally avoids using an IAM user's permanent access keys directly from Terraform.

Instead, the workflow is:

```text
IAM User
   │
   │ AssumeRole request
   ▼
AWS STS
   │
   │ Temporary credentials
   ▼
TerraformExecutionRole
   │
   ├── TerraformNetworkingPolicy
   │
   └── TerraformComputePolicy
   │
   ▼
AWS Infrastructure
```

Terraform therefore operates using temporary credentials associated with the execution role.

---

# 2. Why Use an IAM Role for Terraform?

Terraform needs AWS credentials to communicate with AWS APIs.

A simple approach would be to give Terraform an IAM user's permanent access key and secret access key.

That approach was deliberately avoided in this project.

Instead, Terraform operates through:

```text
Terraform
    ↓
AWS CLI profile
    ↓
AssumeRole
    ↓
TerraformExecutionRole
    ↓
Temporary credentials
    ↓
AWS APIs
```

This provides a separation between the administrative identity and the identity used for infrastructure operations.

The IAM user used to initiate the role assumption does not become the identity Terraform operates as.

After role assumption, AWS evaluates Terraform's infrastructure requests against the permissions granted to `TerraformExecutionRole`.

---

# 3. IAM Identities Used in the Architecture

## Root User

The AWS root user exists at the account level but is not used for normal infrastructure operations.

The root account is reserved for account-level or emergency activities that specifically require root access.

The project therefore does not use the root user's credentials for Terraform or routine AWS CLI operations.

---

## Administrative IAM User

An administrative IAM user named:

```text
Martins
```

is used as the administrative identity for configuring the IAM architecture.

This identity is responsible for actions such as:

* Creating the Terraform execution role
* Creating customer-managed policies
* Attaching policies to the role
* Updating IAM configuration
* Performing administrative verification

The administrative user is the source identity for the role-assumption process.

It is not the identity under which Terraform performs infrastructure operations.

---

# 4. TerraformExecutionRole

The central component of the project is:

```text
TerraformExecutionRole
```

This role represents the identity Terraform uses when communicating with AWS.

The role itself does not automatically have permission to create infrastructure.

Its capabilities come from the policies attached to it.

Current architecture:

```text
TerraformExecutionRole
│
├── Trust Policy
│
├── TerraformNetworkingPolicy
│
└── TerraformComputePolicy
```

The trust policy controls **who can assume the role**.

The permission policies control **what the role can do after it has been assumed**.

These are separate responsibilities.

---

# 5. Trust Policy

The role uses the following trust relationship:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::035680193151:user/Martins"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

The trust policy answers:

> Who is allowed to assume this role?

In this project, the trusted principal is the IAM user:

```text
arn:aws:iam::035680193151:user/Martins
```

The important action is:

```text
sts:AssumeRole
```

The trust policy therefore establishes the relationship required for the administrative identity to request an assumed-role session.

The trust policy does **not** define what Terraform can create.

That responsibility belongs to the role's permission policies.

---

# 6. AWS STS and Temporary Credentials

AWS Security Token Service (STS) provides temporary credentials when an authorized principal assumes an IAM role.

The process is:

```text
Martins IAM User
       │
       │ authenticated request
       ▼
      STS
       │
       │ evaluates role trust relationship
       ▼
TerraformExecutionRole
       │
       │ temporary credentials
       ▼
    Terraform
```

The credentials issued for the assumed-role session are temporary.

Terraform uses those temporary credentials when making AWS API requests.

The effective identity is therefore an assumed-role identity similar to:

```text
arn:aws:sts::035680193151:assumed-role/TerraformExecutionRole/<session-name>
```

This is different from:

```text
arn:aws:iam::035680193151:user/Martins
```

Terraform is therefore not operating directly as the administrative IAM user.

---

# 7. AWS CLI Profiles

The project uses two AWS CLI profiles:

```text
admin
terraform
```

The `admin` profile contains the credentials belonging to the administrative IAM user.

The `terraform` profile does not contain another set of permanent credentials.

Instead, it contains role-assumption configuration similar to:

```ini
[profile terraform]
role_arn = arn:aws:iam::035680193151:role/TerraformExecutionRole
source_profile = admin
region = us-east-1
output = json
```

The relationship is:

```text
terraform profile
       │
       │ source_profile
       ▼
admin profile
       │
       │ source credentials
       ▼
AWS STS AssumeRole
       │
       │ temporary credentials
       ▼
TerraformExecutionRole
```

This allows commands executed with:

```bash
--profile terraform
```

to operate through the Terraform execution role.

---

# 8. Important Permission Boundary Between the Identities

The administrative user's permissions do not automatically become Terraform's permissions after role assumption.

For example:

```text
Martins
│
├── Administrative permissions
│
└── Can configure IAM
```

while:

```text
TerraformExecutionRole
│
├── Networking permissions
└── Compute permissions
```

The two permission sets are separate.

When Terraform makes an AWS API request, AWS evaluates that request against the permissions available to the assumed role.

This separation is a central security property of the architecture.

---

# 9. Permission Policy Architecture

The project uses modular customer-managed policies.

Current policies:

```text
TerraformNetworkingPolicy
TerraformComputePolicy
```

Instead of creating one large policy containing every AWS permission Terraform might ever need, permissions are grouped according to infrastructure capability.

The current model is:

```text
TerraformExecutionRole
│
├── Networking
│   └── TerraformNetworkingPolicy
│
└── Compute
    └── TerraformComputePolicy
```

Future infrastructure requirements can introduce additional policies.

For example:

```text
TerraformExecutionRole
│
├── TerraformNetworkingPolicy
├── TerraformComputePolicy
├── TerraformRDSPolicy       ← future
└── TerraformS3Policy        ← future
```

The role can therefore evolve as the infrastructure project evolves.

---

# 10. TerraformNetworkingPolicy

The networking policy provides Terraform with permissions required to manage AWS networking resources.

The policy includes read permissions such as:

```text
ec2:DescribeVpcs
ec2:DescribeSubnets
ec2:DescribeRouteTables
ec2:DescribeRoutes
ec2:DescribeInternetGateways
ec2:DescribeNatGateways
ec2:DescribeSecurityGroups
ec2:DescribeNetworkInterfaces
```

It also contains lifecycle permissions required for networking resources, including operations involving:

* VPCs
* Subnets
* Route tables
* Routes
* Internet gateways
* NAT gateways
* Elastic IP addresses
* Security groups
* Resource tags

The policy is designed around what Terraform actually needs to inspect and manage the networking infrastructure.

---

# 11. TerraformComputePolicy

The compute policy provides Terraform with permissions required to manage compute-related infrastructure.

It includes permissions for operations involving:

* EC2 instances
* EC2 instance state
* EBS volumes
* EC2 key pairs
* Resource tags

It also includes read permissions such as:

```text
ec2:DescribeInstances
ec2:DescribeInstanceStatus
ec2:DescribeImages
ec2:DescribeKeyPairs
ec2:DescribeVolumes
ec2:DescribeSnapshots
```

Terraform requires read permissions because infrastructure management is not limited to creating resources.

Terraform must also inspect existing AWS resources and their current state so that it can determine what changes are required to reconcile the actual environment with the declared configuration.

---

# 12. Least Privilege

Least privilege is one of the main principles behind this project.

The Terraform execution role is not intended to have unrestricted AWS access.

Instead, permissions are granted according to the infrastructure Terraform is responsible for managing.

The current scope intentionally excludes administrative services such as:

```text
IAM management
Billing
Cost management
Account administration
```

For example, the Terraform role does not have permission to list IAM users.

The test:

```bash
aws iam list-users --profile terraform
```

returns:

```text
AccessDenied
```

This is an expected and successful security result.

The test demonstrates that the Terraform role is not simply inheriting the administrative capabilities of the source IAM user.

---

# 13. "Resource Creation Only" Requires More Than Create Permissions

The goal of this project is sometimes described as allowing Terraform to create infrastructure.

Technically, Terraform normally requires more than `Create` operations.

Terraform manages infrastructure through a reconciliation process.

Depending on the resource, Terraform may need to:

```text
Read
Create
Modify
Delete
```

resources.

For example, Terraform may need to determine whether a VPC already exists, inspect its current configuration, modify it, or remove it when the configuration requires destruction.

Therefore, the project interprets infrastructure-only access as:

> Terraform can manage the lifecycle of the infrastructure within its approved scope, but it does not receive unrelated administrative privileges.

---

# 14. Policy Design Principles

The policy architecture follows four main principles.

## 14.1 Tool-Function Alignment

Permissions are based on what Terraform actually needs to perform.

The policy should reflect infrastructure operations rather than granting broad administrative permissions.

---

## 14.2 Modular Policy Architecture

Permissions are divided according to AWS service or infrastructure capability.

For example:

```text
Networking → TerraformNetworkingPolicy

Compute → TerraformComputePolicy
```

This makes the architecture easier to understand and maintain.

Additional capabilities can be added without rewriting one large policy containing unrelated permissions.

---

## 14.3 Least Privilege

Only the permissions required for the current infrastructure scope are granted.

Services outside that scope remain inaccessible to the Terraform role.

---

## 14.4 Iterative and Adaptive Design

The policy architecture is intentionally not treated as permanently complete.

As infrastructure requirements change, the permissions can change with them.

For example:

```text
Current
│
├── Networking
└── Compute

Future
│
├── Networking
├── Compute
├── RDS
└── S3
```

Permissions are therefore added when there is an actual infrastructure requirement for them.

---

# 15. Testing and Verification

The IAM architecture was tested from the perspective of the Terraform profile rather than only from the administrative profile.

## Identity Test

```bash
aws sts get-caller-identity --profile terraform
```

The result identifies the assumed role:

```text
assumed-role/TerraformExecutionRole/
```

This confirms that the `terraform` profile is operating through the execution role.

---

## Networking Tests

The following operations were tested:

```bash
aws ec2 describe-vpcs --profile terraform

aws ec2 describe-subnets --profile terraform

aws ec2 describe-security-groups --profile terraform
```

These operations were permitted.

Result:

```text
PASS
```

---

## Compute Test

The following operation was tested:

```bash
aws ec2 describe-instances --profile terraform
```

The operation was permitted.

Result:

```text
PASS
```

---

## Unauthorized IAM Test

The following operation was tested:

```bash
aws iam list-users --profile terraform
```

The request was denied.

Result:

```text
PASS — access denied as expected
```

The denial is important because it demonstrates that the Terraform role does not have unrestricted IAM access.

---

## Cost Management Test

Access to cost-management functionality was also tested using the Terraform profile and was denied.

This confirms that the current Terraform execution role is not intended to operate as an AWS billing or cost-management identity.

---

# 16. Explicit Deny and Permissions Boundaries

The current V1 architecture does **not** use:

* A permissions boundary
* A dedicated explicit-deny policy

The current restriction model is based on explicitly granting only the required permissions.

Everything outside those granted permissions is implicitly denied.

This is sufficient for the current V1 implementation.

Future versions may introduce additional controls.

---

## Explicit Deny

An explicit `Deny` can be used to prohibit an action even where an applicable `Allow` exists.

AWS policy evaluation gives explicit denies precedence over applicable allows.

This makes explicit denies useful for enforcing restrictions that must remain prohibited.

They should be introduced deliberately rather than added without a clear security requirement.

---

## Permissions Boundary

A permissions boundary can establish the maximum permissions an IAM principal is allowed to exercise.

Conceptually:

```text
Attached Policies
        │
        ▼
Possible permissions
        │
        ▼
Permissions Boundary
        │
        ▼
Maximum permissions the role can exercise
```

A future permissions boundary can therefore provide an additional security ceiling around the Terraform execution role.

It is not part of the current V1 implementation.

---

# 17. IAM Policy Versions and Git History

This project uses two different forms of version history.

They serve different purposes.

## AWS IAM Policy Versions

AWS customer-managed IAM policies can have multiple policy versions.

A policy update can therefore result in:

```text
Policy
│
├── Version 1
├── Version 2
└── Version 3 ← current/default version
```

The AWS policy version represents the policy document managed by IAM.

---

## Git History

The policy JSON files are also stored in the project repository.

Git records changes such as:

```text
What changed?
When did it change?
Who made the change?
What was the commit message?
```

Git therefore provides the engineering history of the project.

The two systems complement each other:

```text
AWS IAM
└── Runtime policy versions

Git
└── Source-control and engineering history
```

Changing a local JSON file does not automatically create an AWS policy version.

The updated policy must be explicitly deployed to AWS.

---

# 18. Project Structure

```text
terraform-aws-least
```
