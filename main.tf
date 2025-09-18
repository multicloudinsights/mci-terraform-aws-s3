data "aws_caller_identity" "current" {}

locals {
  account_id            = data.aws_caller_identity.current.account_id
  bucket_name           = var.bucket_name == null ? "${random_string.this.result}-${local.account_id}" : var.bucket_name
  logging_bucket_name   = var.logging_bucket_name == null ? "logs-${random_string.this.result}-${local.account_id}" : var.logging_bucket_name
  create_logging_bucket = var.create_logging_bucket == true ? 1 : 0
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
  target_bucket = local.logging_bucket_name
  target_prefix = "${local.logging_bucket_name}/"
}
# End of - S3 Logging Bucket Configuration