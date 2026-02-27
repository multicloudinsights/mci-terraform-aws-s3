variable "bucket_name" {
  type    = string
  default = null
}

variable "default_region" {
  type    = string
  default = "us-east-1"
}

# Start of - Inputs for S3 bucket logging
variable "create_logging_bucket" {
  description = "Set to true if Terraform should create a new S3 bucket to store access logs. Ignored if enable_logging is false or if logging_bucket_name is provided."
  type        = bool
  default     = false
}

variable "logging_bucket_name" {
  description = "The name of an existing S3 bucket to use for storing access logs. Leave null to allow Terraform to generate a new bucket name (if create_logging_bucket is true)."
  type        = string
  default     = null
}

variable "enable_logging" {
  description = "Enable or disable access logging for the main S3 bucket (bucket-one). If set to false, no logging configuration or logging bucket will be applied or created."
  type        = bool
  default     = false
}
# End of - Inputs for S3 bucket logging

variable "kms_master_key_id" {
  type    = string
  default = null
}

# Start of - Public Access Block
variable "block_public_acls" {
  type    = bool
  default = true
}

variable "block_public_policy" {
  type    = bool
  default = true
}

variable "ignore_public_acls" {
  type    = bool
  default = true
}

variable "restrict_public_buckets" {
  type    = bool
  default = true
}
# End of - Public Access Block

# Start of - Bucket Policy
variable "enable_bucket_policy" {
  description = "Enable or disable the S3 bucket policy. When true and bucket_policy is null, a default policy enforcing HTTPS-only access is applied."
  type        = bool
  default     = true
}

variable "bucket_policy" {
  description = "Custom IAM policy JSON to attach to the S3 bucket. If null, the default policy (deny all non-HTTPS requests) is applied when enable_bucket_policy is true."
  type        = string
  default     = null
}
# End of - Bucket Policy

# Start of - Lifecycle Rules
variable "enable_lifecycle_rules" {
  description = "Enable or disable lifecycle rules on the main S3 bucket."
  type        = bool
  default     = true
}

variable "lifecycle_rules" {
  description = "Custom lifecycle rules for the S3 bucket. If null, a default rule is applied: transitions objects to STANDARD_IA at 30 days, GLACIER at 90 days, expires them at 365 days, expires noncurrent versions at 90 days, and aborts incomplete multipart uploads after 7 days."
  type = list(object({
    id            = string
    status        = string
    filter_prefix = optional(string, "")
    transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])
    expiration_days                        = optional(number)
    noncurrent_version_expiration_days     = optional(number)
    noncurrent_version_transitions = optional(list(object({
      noncurrent_days = number
      storage_class   = string
    })), [])
    abort_incomplete_multipart_upload_days = optional(number)
  }))
  default = null
}
# End of - Lifecycle Rules