terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28"
    }
  }
}

# Credentials come from AWS_PROFILE (see .env); the region is fixed by D-001.
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      project    = "2026_eks_for_data"
      managed-by = "terraform"
    }
  }
}

locals {
  name = "eks-for-data"
}
