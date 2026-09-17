# AWS Terraform Least-Privilege Architecture

## 1. Purpose

This document describes the technical architecture used to allow Terraform to manage AWS infrastructure through an IAM role.

The architecture separates the administrative identity used to configure AWS IAM from the identity Terraform uses to perform infrastructure operations.

The design consists of:

* An administrative IAM user
* A Terraform execution role
* A role trust policy
* AWS Security Token Service (STS)
* Temporary credentials
* Modular Terraform permission policies
* An AWS CLI profile configured for role assumption
* AWS infrastructure resources

The architecture is designed to provide Terraform with only the permissions required for its current infrastructure scope.

---

# 2. High-Level Architecture

The role-assumption flow is:

```text
IAM User: Martins
       │
       │ sts:AssumeRole
       ▼
AWS STS
       │
       │ temporary credentials
       ▼
TerraformExecutionRole
       │
       ├── TerraformNetworkingPolicy
       │
       └── TerraformComputePolicy
       │
       ▼
Terraform
       │
       ▼
AWS Infrastructure
```

The administrative IAM user is the source identity for the role-assumption request.

Terraform does not operate using the administrative user's identity after the role has been assumed.

---

# 3. Administrative Identity

The administrative identity is the IAM user:

```text
Martins
```

Its ARN is:

```text
arn:aws:iam::035680193151:user/Martins
```

This identity is used for administrative configuration tasks such as:

* Creating the Terraform execution role
* Creating customer-managed policies
* Attaching policies to the role
* Updating IAM configuration
* Verifying IAM resources

The administrative identity is not intended to be the execution identity for Terraform.

---

# 4. Terraform Execution Role

The Terraform execution role is:

```text
TerraformExecutionRole
```

Its purpose is to provide a dedicated AWS identity for infrastructure automation.

The role does not receive permissions merely because it exists.

Its capabilities are determined by the policies attached to it.

The current architecture is:

```text
TerraformExecutionRole
│
├── Trust Policy
│
├── TerraformNetworkingPolicy
│
└── TerraformComputePolicy
```

The trust policy and permission policies have different responsibilities.

---

# 5. Trust Relationship

The role's trust policy allows the administrative IAM user to perform:

```text
sts:AssumeRole
```

The trust relationship answers:

> Who is allowed to assume this role?

It does not answer:

> What can the role do?

That second question is answered by the role's permission policies.

The current trust relationship identifies:

```text
arn:aws:iam::035680193151:user/Martins
```

as the trusted principal.

---

# 6. AWS STS

AWS Security Token Service provides temporary credentials when an authorized principal assumes an IAM role.

The process is:

```text
Martins
   │
   │ AssumeRole request
   ▼
AWS STS
   │
   │ validates the role trust relationship
   ▼
TerraformExecutionRole
   │
   │ temporary session credentials
   ▼
Terraform
```

The resulting session has an assumed-role identity similar to:

```text
arn:aws:sts::035680193151:assumed-role/TerraformExecutionRole/<session-name>
```

This identity is different from the original IAM user:

```text
arn:aws:iam::035680193151:user/Martins
```

---

# 7. AWS CLI Profile Architecture

The AWS CLI uses two profiles for this workflow:

```text
admin
terraform
```

The `admin` profile represents the administrative IAM user.

The `terraform` profile is configured to use the administrative profile as its source profile and assume the Terraform execution role.

Conceptually:

```text
terraform profile
       │
       │ source_profile = admin
       ▼
admin credentials
       │
       ▼
AWS STS
       │
       ▼
TerraformExecutionRole
```

A typical configuration is:

```ini
[profile terraform]
role_arn = arn:aws:iam::035680193151:role/TerraformExecutionRole
source_profile = admin
region = us-east-1
output = json
```

The `terraform` profile does not represent another IAM user with another permanent access key.

It represents a role-assumption configuration.

---

# 8. Permission Policy Architecture

The Terraform role currently has two customer-managed permission policies.

```text
TerraformExecutionRole
│
├── TerraformNetworkingPolicy
│
└── TerraformComputePolicy
```

The policies are separated according to infrastructure capability.

This makes the permission model easier to understand and allows individual capabilities to be added or removed as requirements change.

---

# 9. Networking Permissions

`TerraformNetworkingPolicy` provides the permissions required for Terraform to inspect and manage the current networking scope.

The policy covers operations associated with resources including:

* VPCs
* Subnets
* Route tables
* Routes
* Internet gateways
* NAT gateways
* Elastic IP addresses
* Security groups
* Network interfaces
* Availability zones
* Resource tags

Read permissions are included because Terraform needs to inspect existing AWS resources and their current state.

Lifecycle permissions are included for resources Terraform is expected to create, modify, associate, disassociate, or delete.

---

# 10. Compute Permissions

`TerraformComputePolicy` provides the permissions required for the current compute scope.

The policy covers operations involving:

* EC2 instances
* EC2 instance state
* AMIs and images
* EC2 key pairs
* EBS volumes
* EBS snapshots
* Resource tags

Terraform requires both read and lifecycle permissions because infrastructure management involves comparing declared configuration with the current AWS environment.

---

# 11. Current Infrastructure Boundary

The current execution role is intentionally limited to networking and compute capabilities.

Conceptually:

```text
TerraformExecutionRole
│
├── Networking
│   └── Allowed
│
├── Compute
│   └── Allowed
│
├── IAM administration
│   └── Not granted
│
├── Billing / Cost Management
│   └── Not granted
│
└── Other AWS services
    └── Not granted unless explicitly added
```

This boundary is expected to change only when infrastructure requirements change.

---

# 12. Future Architecture

Additional capabilities can be introduced as separate policies.

For example:

```text
TerraformExecutionRole
│
├── TerraformNetworkingPolicy
├── TerraformComputePolicy
├── TerraformRDSPolicy       ← future
└── TerraformS3Policy        ← future
```

Additional security controls may also be introduced:

```text
TerraformExecutionRole
│
├── Permission Policies
├── Permissions Boundary     ← future
└── Explicit Deny Controls   ← future
```

These future components are not part of the current V1 implementation.

---

# 13. Architecture Diagram

The project includes a visual representation of the role-assumption architecture in:

```text
diagrams/role-assumption-architecture.png
```

The diagram illustrates:

* The administrative identity
* AWS STS
* The Terraform execution role
* Trust and permission policies
* Temporary credentials
* Terraform
* AWS infrastructure

The diagram should be read together with this document.

---

# 14. Architecture Summary

The architecture establishes a separation between:

```text
Administrative identity
        ≠
Terraform execution identity
```

and:

```text
Trust policy
        ≠
Permission policy
```

The administrative identity is responsible for establishing and managing the IAM architecture.

Terraform receives temporary credentials for the execution role and operates within the permissions granted to that role.

This creates a dedicated execution identity for infrastructure automation without requiring Terraform to use the administrative user's permanent identity directly.
