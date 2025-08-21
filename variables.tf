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