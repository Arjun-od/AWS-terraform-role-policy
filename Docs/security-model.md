# AWS Terraform Least-Privilege Security Model

## 1. Purpose

This document describes the security principles and controls used in the Terraform AWS IAM architecture.

The primary security objective is to prevent Terraform from receiving unnecessary AWS privileges while still providing the permissions required to manage infrastructure.

The model is based on:

* Least privilege
* Separation of identities
* Temporary credentials
* Modular permission policies
* Controlled role assumption
* Permission testing
* Incremental policy expansion

---

# 2. Security Objective

Terraform requires AWS API access to provision and manage infrastructure.

The security objective is not to prevent Terraform from accessing AWS.

The objective is to ensure that Terraform's AWS access is limited to the infrastructure responsibilities assigned to it.

The desired relationship is:

```text
Terraform
   │
   ▼
Required infrastructure permissions
   │
   ▼
AWS infrastructure
```

rather than:

```text
Terraform
   │
   ▼
Broad administrative permissions
   │
   ▼
Entire AWS account
```

---

# 3. Separation of Identities

The architecture separates the administrative identity from the infrastructure execution identity.

```text
Administrative Identity
        │
        │ establishes IAM configuration
        ▼
TerraformExecutionRole
        │
        │ performs infrastructure operations
        ▼
AWS Infrastructure
```

The administrative IAM user's permissions do not automatically become the permissions of the Terraform execution role.

The role has its own permission policies.

This separation reduces the scope of the identity used by infrastructure automation.

---

# 4. Permanent vs Temporary Credentials

A major security decision in this project is avoiding the use of an administrative IAM user's permanent credentials as Terraform's execution identity.

The workflow instead uses:

```text
Administrative credentials
        │
        ▼
AWS STS AssumeRole
        │
        ▼
Temporary role credentials
        │
        ▼
Terraform
```

The temporary credentials belong to the assumed-role session.

Terraform therefore operates as:

```text
assumed-role/TerraformExecutionRole/<session>
```

rather than directly as:

```text
user/Martins
```

---

# 5. Trust Policy vs Permission Policy

These two policy types serve different security functions.

## Trust Policy

The trust policy answers:

> Who can assume this role?

The current trust relationship permits the `Martins` IAM user to assume:

```text
TerraformExecutionRole
```

through:

```text
sts:AssumeRole
```

---

## Permission Policies

Permission policies answer:

> What can the role do after it has been assumed?

The current permission policies are:

```text
TerraformNetworkingPolicy
TerraformComputePolicy
```

These policies define the infrastructure operations available to Terraform.

Keeping these concepts separate makes the IAM architecture easier to reason about.

---

# 6. Least Privilege

Least privilege means providing an identity only the permissions necessary for its intended responsibilities.

In this project, Terraform is intended to manage infrastructure rather than administer the AWS account.

Therefore, the Terraform role is not granted broad IAM administration, billing, or account-management permissions.

The permission model is scoped around the infrastructure capabilities currently required.

---

# 7. Modular Policies

Permissions are separated into policies based on infrastructure capability.

Current implementation:

```text
TerraformNetworkingPolicy
TerraformComputePolicy
```

This avoids creating one large policy containing unrelated permissions.

The modular approach provides several benefits:

* Easier policy review
* Easier troubleshooting
* Clearer ownership of permissions
* Easier expansion
* Easier removal of unused capabilities
* Better visibility into the role's effective purpose

For example, if RDS becomes a requirement, an RDS-specific policy can be introduced instead of expanding an unrelated networking policy.

---

# 8. Current Implicit-Deny Model

The current V1 implementation does not contain a dedicated explicit-deny policy.

Instead, the role receives explicit `Allow` permissions for the capabilities it needs.

Actions for which the role has no applicable permission are denied through AWS's policy evaluation process.

Conceptually:

```text
Explicit Allow
      │
      ▼
Required Terraform operation
      │
      ▼
Allowed


No applicable Allow
      │
      ▼
Unapproved operation
      │
      ▼
Implicitly denied
```

For example, the Terraform role can perform approved EC2 networking operations but cannot list IAM users.

---

# 9. Explicit Deny

An explicit `Deny` is a stronger policy control than simply omitting an `Allow`.

When an applicable explicit deny exists, it takes precedence over an applicable allow.

This can be useful when an operation must remain prohibited even if another policy could otherwise grant access.

However, the current V1 project does not rely on explicit deny policies.

Explicit deny controls are considered a future security enhancement where they provide a specific, justified control.

---

# 10. Permissions Boundary

A permissions boundary is another future security control.

A permissions boundary establishes the maximum permissions that an IAM principal can exercise.

Conceptually:

```text
Attached Permissions
        │
        ▼
Potential Permissions
        │
        ▼
Permissions Boundary
        │
        ▼
Maximum Effective Permission Ceiling
```

If a policy later attempts to grant permissions outside the boundary, those permissions cannot become effective for the principal.

A permissions boundary is therefore different from an ordinary permission policy.

A permission policy grants capabilities.

A permissions boundary limits the maximum capability set.

The current V1 role does not have a permissions boundary.

---

# 11. Administrative and Terraform Permission Separation

The administrative user has capabilities required to configure IAM.

The Terraform execution role does not inherit those capabilities simply because the administrative user was the source identity for the role assumption.

For example:

```text
Martins
├── IAM administration
└── Role configuration
```

while:

```text
TerraformExecutionRole
├── Networking
└── Compute
```

The two permission sets are intentionally different.

---

# 12. Unauthorized Access Testing

Security controls should be verified through both positive and negative tests.

A positive test asks:

> Can Terraform perform an operation it is supposed to perform?

A negative test asks:

> Is Terraform prevented from performing an operation outside its scope?

For example:

```bash
aws ec2 describe-vpcs --profile terraform
```

should succeed.

Whereas:

```bash
aws iam list-users --profile terraform
```

should be denied.

Both results are useful evidence.

---

# 13. Credential Protection

The project does not store permanent AWS credentials in the repository.

The repository should contain:

* Policy documents
* Scripts
* Documentation
* Configuration examples
* Architecture diagrams

The repository should not contain:

* AWS access keys
* AWS secret access keys
* Private keys
* Credential files
* `.env` files containing secrets

The AWS CLI credential configuration remains outside the project repository.

---

# 14. Policy Evolution

Security requirements change as infrastructure changes.

The project therefore treats permissions as an evolving configuration rather than a permanently fixed document.

The intended process is:

```text
Infrastructure requirement
        │
        ▼
Identify required AWS operations
        │
        ▼
Update appropriate policy
        │
        ▼
Review change
        │
        ▼
Deploy policy version
        │
        ▼
Test permissions
        │
        ▼
Commit change to Git
```

This keeps permission changes connected to actual infrastructure requirements.

---

# 15. AWS IAM Policy Versions and Git

Two forms of change history are used.

### AWS IAM Policy Versions

AWS maintains versions of customer-managed policies.

These represent policy documents deployed to AWS.

### Git

Git tracks the source files and engineering history.

Git records:

* The policy changes
* Commit messages
* Project evolution
* Configuration changes
* Documentation changes

The two systems are complementary.

```text
AWS IAM
└── Runtime policy versions

Git
└── Source and engineering history
```

A change to a local JSON file does not automatically modify the policy in AWS.

The updated policy must be explicitly deployed.

---

# 16. Security Limitations of V1

The current implementation intentionally represents an initial least-privilege architecture rather than a final security model.

Current limitations include:

* No permissions boundary
* No dedicated explicit-deny controls
* Some EC2 permissions use broad resource scope
* Additional AWS services have not yet been included
* Resource-level restrictions can be made more granular where AWS supports them and the project requires them

These limitations are documented rather than hidden.

The architecture is designed to evolve as the project becomes more sophisticated.

---

# 17. Future Security Improvements

Potential future improvements include:

```text
Permissions Boundary
Explicit Deny Controls
More granular resource-level permissions
RDS-specific policy
S3-specific policy
Additional service-specific policies
Regular permission review
Automated policy validation
```

Each improvement should be introduced based on a concrete requirement rather than adding security mechanisms without a defined purpose.

---

# 18. Security Architecture Diagram

The project includes:

```text
diagrams/security-architecture.png
```

The diagram represents:

* Administrative identity
* Terraform execution identity
* Current allowed permissions
* Restricted capabilities
* Least-privilege boundaries
* Future security controls

The diagram should be interpreted alongside this document.

---

# 19. Security Model Summary

The security model can be summarized as:

```text
Separate identities
        +
Temporary credentials
        +
Controlled role assumption
        +
Modular permission policies
        +
Least privilege
        +
Positive and negative testing
        +
Incremental security improvements
```

The objective is to make infrastructure automation capable of performing its intended work without unnecessarily turning the automation identity into an administrative identity.
