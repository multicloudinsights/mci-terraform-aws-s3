terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.9"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.7"
    }
  }

  required_version = ">= 1.10"
}

provider "aws" {
  region = var.default_region
}