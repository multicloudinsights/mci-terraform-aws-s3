data "aws_caller_identity" "current" {}

locals {
  account_id            = data.aws_caller_identity.current.account_id
  bucket_name           = var.bucket_name == null ? "${random_string.this.result}-${local.account_id}" : var.bucket_name
  logging_bucket_name   = var.logging_bucket_name == null ? "logs-${random_string.this.result}-${local.account_id}" : var.logging_bucket_name
  create_logging_bucket = var.create_logging_bucket == true ? 1 : 0

  default_lifecycle_rules = [
    {
      id            = "default"
      status        = "Enabled"
      filter_prefix = ""
      transitions = [
        { days = 30, storage_class = "STANDARD_IA" },
        { days = 90, storage_class = "GLACIER" },
      ]
      expiration_days                        = 365
      noncurrent_version_expiration_days     = 90
      noncurrent_version_transitions = [
        { noncurrent_days = 30, storage_class = "STANDARD_IA" },
      ]
      abort_incomplete_multipart_upload_days = 7
    }
  ]
  lifecycle_rules = var.lifecycle_rules != null ? var.lifecycle_rules : local.default_lifecycle_rules
}

resource "random_string" "this" {
  length  = 10
  special = false
  lower   = true
  upper   = false
}

resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name

  tags = {
    Name = local.bucket_name
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms" # other supported - AES256, aws:kms:dsse
      kms_master_key_id = var.kms_master_key_id != null ? var.kms_master_key_id : "aws/s3"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

# Start of - Bucket Policy
#################################################
# 1. Default policy enforces HTTPS-only access
# 2. User can supply a custom policy JSON
#################################################
data "aws_iam_policy_document" "default_bucket_policy" {
  statement {
    sid    = "DenyNonHTTPS"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  count  = var.enable_bucket_policy ? 1 : 0
  bucket = aws_s3_bucket.this.id
  policy = var.bucket_policy != null ? var.bucket_policy : data.aws_iam_policy_document.default_bucket_policy.json

  depends_on = [aws_s3_bucket_public_access_block.this]
}
# End of - Bucket Policy

# Start of - Lifecycle Rules
#####################################################
# 1. Default rule transitions objects to cheaper tiers
# 2. Noncurrent versions expired to control costs
# 3. Incomplete multipart uploads cleaned up
# 4. User can supply custom lifecycle rules
#####################################################
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.enable_lifecycle_rules ? 1 : 0
  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = local.lifecycle_rules

    content {
      id     = rule.value.id
      status = rule.value.status

      filter {
        prefix = rule.value.filter_prefix
      }

      dynamic "transition" {
        for_each = rule.value.transitions
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [rule.value.expiration_days] : []
        content {
          days = expiration.value
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration_days != null ? [rule.value.noncurrent_version_expiration_days] : []
        content {
          noncurrent_days = noncurrent_version_expiration.value
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = rule.value.noncurrent_version_transitions
        content {
          noncurrent_days = noncurrent_version_transition.value.noncurrent_days
          storage_class   = noncurrent_version_transition.value.storage_class
        }
      }

      dynamic "abort_incomplete_multipart_upload" {
        for_each = rule.value.abort_incomplete_multipart_upload_days != null ? [rule.value.abort_incomplete_multipart_upload_days] : []
        content {
          days_after_initiation = abort_incomplete_multipart_upload.value
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}
# End of - Lifecycle Rules

# Start of - S3 Logging Bucket Configuration
############################################
# 1. Create Logging Bucket
# 2. Enable Encryption in Logging Bucket
# 3. Block Public Access to Logging Bucket
# 4. Enable Logging for Main Bucket
############################################
resource "aws_s3_bucket" "logging" {
  count = local.create_logging_bucket

  bucket = local.logging_bucket_name

  tags = {
    Name = local.logging_bucket_name
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logging" {
  count = local.create_logging_bucket

  bucket = aws_s3_bucket.logging[count.index].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms" # other supported - AES256, aws:kms:dsse
      kms_master_key_id = var.kms_master_key_id != null ? var.kms_master_key_id : "aws/s3"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logging" {
  count = local.create_logging_bucket

  bucket = aws_s3_bucket.logging[count.index].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "this" {
  count = var.enable_logging == true ? 1 : 0

  bucket        = aws_s3_bucket.this.id
  target_bucket = var.create_logging_bucket ? aws_s3_bucket.logging[0].id : var.logging_bucket_name
  target_prefix = "${local.logging_bucket_name}/"

  lifecycle {
    precondition {
      condition     = var.create_logging_bucket == true || var.logging_bucket_name != null
      error_message = "When enable_logging is true, either create_logging_bucket must be true or logging_bucket_name must be provided."
    }
  }
}
# End of - S3 Logging Bucket Configuration