# mci-terraform-aws-s3

Terraform configuration that provisions a secure, production-ready AWS S3 bucket. All security best practices are applied by default — encryption, public access blocking, HTTPS enforcement, versioning, and lifecycle cost management — with simple toggles to customise each feature.

---

## What it creates

| Resource | Always created | Conditional |
|----------|:--------------:|:-----------:|
| S3 bucket (main) | ✓ | |
| KMS server-side encryption | ✓ | |
| Versioning | ✓ | |
| Public access block | ✓ | |
| HTTPS-only bucket policy | ✓ (default on) | toggle off |
| Lifecycle rules | ✓ (default on) | toggle off / customise |
| S3 access log bucket | | `create_logging_bucket = true` |
| Access logging on main bucket | | `enable_logging = true` |

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- AWS credentials configured locally (see [Local development](#local-development))
- An AWS account with permissions to create S3 buckets and IAM policies

---

## Quick start

```hcl
# Simplest possible usage — all secure defaults applied automatically
# No variables required. Bucket name and region default to auto-generated + us-east-1.
```

```bash
terraform init
terraform plan
terraform apply
```

To give the bucket a name and enable logging:

```hcl
# terraform.tfvars
bucket_name            = "my-app-data"
default_region         = "eu-west-1"
enable_logging         = true
create_logging_bucket  = true
```

---

## Inputs

### General

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `bucket_name` | `string` | `null` | Name for the S3 bucket. If null, a unique name is auto-generated using a random string and your AWS account ID. |
| `default_region` | `string` | `us-east-1` | AWS region to deploy into. |
| `kms_master_key_id` | `string` | `null` | KMS key ID or ARN for encryption. If null, the AWS-managed `aws/s3` key is used. |

### Public access block

All four flags default to `true`, meaning the bucket is fully private. Only change these if you have a specific use case that requires public access (e.g. a static website).

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `block_public_acls` | `bool` | `true` | Block public ACLs from being set. |
| `block_public_policy` | `bool` | `true` | Block public bucket policies. |
| `ignore_public_acls` | `bool` | `true` | Ignore any existing public ACLs. |
| `restrict_public_buckets` | `bool` | `true` | Restrict public access regardless of policy. |

### Bucket policy

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_bucket_policy` | `bool` | `true` | When true, attaches a bucket policy. |
| `bucket_policy` | `string` | `null` | Custom policy JSON. If null, the built-in HTTPS-only policy is used. |

### Access logging

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_logging` | `bool` | `false` | Enable access logs on the main bucket. Requires either `create_logging_bucket = true` or a `logging_bucket_name`. |
| `create_logging_bucket` | `bool` | `false` | Create a dedicated S3 bucket to receive the logs. |
| `logging_bucket_name` | `string` | `null` | Name of an existing bucket to write logs to. If null and `create_logging_bucket` is true, a name is auto-generated. |

### Lifecycle rules

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_lifecycle_rules` | `bool` | `true` | Enable or disable lifecycle rules. |
| `lifecycle_rules` | `list(object)` | `null` | Custom rules. If null, the built-in default rule is applied (see below). |

---

## Outputs

| Output | Description |
|--------|-------------|
| `bucket_name` | The name (ID) of the created S3 bucket. |
| `bucket_arn` | The ARN of the bucket. Use this when granting IAM permissions. |
| `regional_bucket_domain` | The regional domain name (e.g. for CloudFront origins). |

---

## Default behaviours explained

### Default bucket policy — HTTPS only

When `enable_bucket_policy = true` and no custom `bucket_policy` is provided, the following policy is attached:

- **Denies all S3 actions** on the bucket and its objects if the request does not use HTTPS (`aws:SecureTransport = false`).
- This prevents data from being read or written over unencrypted HTTP connections.

To use a custom policy instead:

```hcl
bucket_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [
    {
      Sid       = "AllowSpecificRole"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::123456789012:role/my-app-role" }
      Action    = ["s3:GetObject"]
      Resource  = "arn:aws:s3:::my-bucket/*"
    }
  ]
})
```

To turn off the policy entirely:

```hcl
enable_bucket_policy = false
```

---

### Default lifecycle rule

When `enable_lifecycle_rules = true` and no custom `lifecycle_rules` are provided, this rule runs on all objects:

| Day | Action |
|-----|--------|
| 30 | Move current objects to **STANDARD_IA** (infrequent access — cheaper storage) |
| 30 (noncurrent) | Move old versions to **STANDARD_IA** |
| 90 | Move current objects to **GLACIER** (archive — very cheap, slow retrieval) |
| 90 (noncurrent) | **Delete** old versions |
| 365 | **Delete** current objects |
| 7 days after start | **Abort** incomplete multipart uploads |

To define your own rules:

```hcl
lifecycle_rules = [
  {
    id            = "raw-data"
    status        = "Enabled"
    filter_prefix = "raw/"          # applies only to objects under raw/
    transitions = [
      { days = 60,  storage_class = "STANDARD_IA" },
      { days = 180, storage_class = "GLACIER" }
    ]
    expiration_days                        = 730
    noncurrent_version_expiration_days     = 30
    abort_incomplete_multipart_upload_days = 3
  }
]
```

To turn off lifecycle rules entirely:

```hcl
enable_lifecycle_rules = false
```

---

## Local development

### 1. Configure AWS credentials

The recommended way is to use AWS SSO or a named profile:

```bash
aws configure sso          # one-time SSO setup
aws sso login              # log in before running Terraform
export AWS_PROFILE=my-profile
```

Or with static credentials (not recommended for production):

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=us-east-1
```

### 2. Initialise Terraform

```bash
terraform init
```

### 3. Preview changes

```bash
terraform plan
```

Always review the plan output before applying. Check that:
- The correct bucket name is shown
- The expected resources are being created (not destroyed and recreated)
- No sensitive values are printed in plain text

### 4. Apply

```bash
terraform apply
```

Type `yes` when prompted, or use `-auto-approve` in scripts (never in production manually).

### 5. Check outputs

```bash
terraform output
```

### 6. Destroy (when done)

```bash
terraform destroy
```

---

## Testing your configuration

### Format check

Ensures all `.tf` files are consistently formatted:

```bash
terraform fmt -check -diff
```

To auto-fix formatting:

```bash
terraform fmt
```

### Validate

Checks the configuration is syntactically valid and internally consistent (does not connect to AWS):

```bash
terraform validate
```

### Security scan with Checkov

[Checkov](https://www.checkov.io/) scans for misconfigurations before you apply:

```bash
# Install
pip install checkov

# Run against this directory
checkov --framework terraform -d .
```

Review findings and address any `FAILED` checks relevant to your use case.

---

## Pipelines

Two CI/CD pipelines are provided. Use whichever matches your hosting platform.

### When to use GitHub Actions (`.github/workflows/terraform.yml`)

Use this if your code is hosted on **GitHub**.

**Pipeline jobs:**

```
format ──┐
          ├──> plan ──> apply  (main branch push only, requires approval)
checkov ─┘
```

| Job | Runs on | Blocks pipeline? |
|-----|---------|-----------------|
| `format` | Every PR + push to main | Yes — plan won't run if fmt fails |
| `checkov` | Every PR + push to main | No — findings reported but non-blocking |
| `plan` | Every PR + push to main | Yes — apply won't run if plan fails |
| `apply` | Push to main only | Requires environment approval |

**Setup required before first use:**

1. Create an IAM role in AWS with a trust policy for GitHub OIDC (`token.actions.githubusercontent.com`)
2. Add the role ARN as a GitHub Actions secret named `AWS_ROLE_ARN`
3. In GitHub repository settings → Environments, create a `production` environment and add required reviewers

> The pipeline uses OIDC (keyless auth) — no long-lived AWS credentials are stored in GitHub.

---

### When to use GitLab CI (`.gitlab-ci.yml`)

Use this if your code is hosted on **GitLab**.

**Pipeline stages:**

```
static-analysis ──> prepare ──> validate ──> build ──> deploy
(format+checkov)   (init)                   (plan)   (manual apply)
```

| Stage | Jobs | Blocks pipeline? |
|-------|------|-----------------|
| `static-analysis` | `format`, `checkov` (parallel) | format blocks; checkov non-blocking |
| `prepare` | `init` | Yes |
| `validate` | `validate` | Yes |
| `build` | `plan` | Yes |
| `deploy` | `apply` (manual trigger) | N/A — manual |

**Setup required before first use:**

1. Configure AWS credentials as GitLab CI/CD variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) or set up an IAM role with GitLab OIDC
2. Ensure a runner with the `docker` tag is available for the Checkov job
3. To disable the Checkov job, set the CI variable `SAST_DISABLED` to any value

---

## Security best practices applied

| Practice | How it's implemented |
|----------|---------------------|
| **Encryption at rest** | KMS server-side encryption on all objects (`aws:kms`). Defaults to the AWS-managed `aws/s3` key; a customer-managed key can be provided via `kms_master_key_id`. |
| **Encryption in transit** | Default bucket policy denies all `s3:*` actions over HTTP (`aws:SecureTransport = false`). |
| **No public access** | All four public access block flags are enabled by default. Buckets cannot be made public accidentally. |
| **Versioning** | Enabled on the main bucket. Protects against accidental deletion and overwrites. |
| **Lifecycle cost controls** | Objects are automatically transitioned to cheaper storage tiers and expired, preventing unbounded storage growth. |
| **Logging** | Optional access logging to a dedicated, encrypted, fully private log bucket. |
| **Logging bucket isolation** | The log bucket has its own encryption and public access block hardcoded to `true` — it cannot be loosened via variables. |
| **Keyless CI authentication** | The GitHub Actions pipeline uses OIDC to assume an IAM role per-run. No static AWS credentials are stored in GitHub. |
| **Least privilege CI permissions** | GitHub Actions workflow declares `contents: read` and `id-token: write` only. |
| **Plan before apply** | Both pipelines require a successful `terraform plan` before apply runs. The GitHub pipeline passes the plan file as an artifact so apply uses exactly what was reviewed. |
| **Manual apply gate** | Apply is a manual step in both pipelines and is restricted to the default/main branch only. GitHub additionally supports required reviewer approval via environments. |
| **Security scanning** | Checkov SAST scan runs on every pipeline to flag infrastructure misconfigurations before they reach AWS. |
| **Dependency ordering** | `depends_on` ensures the public access block is in place before the bucket policy is applied, and versioning is enabled before lifecycle rules are created. |

---

## File structure

```
.
├── main.tf           # All AWS resources
├── variables.tf      # Input variable definitions
├── output.tf         # Output values
├── providers.tf      # Terraform and provider version constraints
├── .github/
│   └── workflows/
│       └── terraform.yml   # GitHub Actions pipeline
└── .gitlab-ci.yml          # GitLab CI pipeline
```
