# The account ID makes the global bucket names unique (D-015)
data "aws_caller_identity" "current" {}

# Raw data layer: destination of the Airbyte Parquet files
module "s3_bronze" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.17.0"

  bucket        = "${local.name}-bronze-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  attach_deny_insecure_transport_policy = true
}

# Airbyte logs, state and workload output (D-009)
module "s3_airbyte" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.17.0"

  bucket        = "${local.name}-airbyte-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  attach_deny_insecure_transport_policy = true
}

# IRSA role for the Airbyte ServiceAccount, used by every Airbyte pod (D-008)
module "airbyte_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.8.2"

  name            = "${local.name}-airbyte"
  use_name_prefix = false

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["airbyte:airbyte-admin"]
    }
  }

  # Airbyte S3 destination policy, limited to the two buckets
  permissions = {
    S3Buckets = {
      actions = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:PutObjectAcl",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:AbortMultipartUpload",
        "s3:GetBucketLocation",
      ]
      resources = [
        module.s3_bronze.s3_bucket_arn,
        "${module.s3_bronze.s3_bucket_arn}/*",
        module.s3_airbyte.s3_bucket_arn,
        "${module.s3_airbyte.s3_bucket_arn}/*",
      ]
    }
  }
}
