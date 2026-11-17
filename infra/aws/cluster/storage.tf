# The account ID makes the global bucket names unique (D-015)
data "aws_caller_identity" "current" {}

# The buckets live in infra/aws/data (D-077); their ARNs are built from the fixed name pattern
locals {
  bucket_arn = {
    for b in ["bronze", "silver", "airbyte", "airflow"] :
    b => "arn:aws:s3:::${local.name}-${b}-${data.aws_caller_identity.current.account_id}"
  }
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
        local.bucket_arn.bronze,
        "${local.bucket_arn.bronze}/*",
        local.bucket_arn.airbyte,
        "${local.bucket_arn.airbyte}/*",
      ]
    }
  }
}

# IRSA role for the DuckDB ServiceAccount: read-only on the bronze bucket (D-008, D-033)
module "duckdb_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.8.2"

  name            = "${local.name}-duckdb"
  use_name_prefix = false

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["duckdb:duckdb"]
    }
  }

  permissions = {
    S3BronzeRead = {
      actions = [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:GetBucketLocation",
      ]
      resources = [
        local.bucket_arn.bronze,
        "${local.bucket_arn.bronze}/*",
      ]
    }
  }
}


# IRSA role for the Spark jobs: read-only on the bronze bucket; silver access is vended by Polaris
# (D-008, D-049)
module "spark_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.8.2"

  name            = "${local.name}-spark"
  use_name_prefix = false

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["spark:spark"]
    }
  }

  permissions = {
    S3BronzeRead = {
      actions = [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:GetBucketLocation",
      ]
      resources = [
        local.bucket_arn.bronze,
        "${local.bucket_arn.bronze}/*",
      ]
    }
  }
}

# IRSA role for Polaris: it only assumes the silver data role, to write table metadata and to vend
# per-table credentials (D-049). The ARN is built from the name to avoid a dependency cycle.
module "polaris_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.8.2"

  name            = "${local.name}-polaris"
  use_name_prefix = false

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["polaris:polaris"]
    }
  }

  permissions = {
    AssumeSilverData = {
      actions   = ["sts:AssumeRole"]
      resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.name}-silver-data"]
    }
  }
}

# Read and write on the silver bucket, assumable only by Polaris (D-049)
resource "aws_iam_role" "silver_data" {
  name = "${local.name}-silver-data"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = module.polaris_irsa.arn }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "silver_data" {
  name = "S3SilverReadWrite"
  role = aws_iam_role.silver_data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:AbortMultipartUpload",
        "s3:ListBucketMultipartUploads",
      ]
      Resource = [
        local.bucket_arn.silver,
        "${local.bucket_arn.silver}/*",
      ]
    }]
  })
}


# IRSA role for the Airflow components that write or read task logs: task pods (KubernetesExecutor
# worker), the API
# server and the triggerer; read and write on the logs bucket only (D-008, D-072)
module "airflow_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.8.2"

  name            = "${local.name}-airflow"
  use_name_prefix = false

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "airflow:airflow-worker-kubernetes",
        "airflow:airflow-api-server",
        "airflow:airflow-triggerer",
      ]
    }
  }

  permissions = {
    S3AirflowLogsReadWrite = {
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation",
      ]
      resources = [
        local.bucket_arn.airflow,
        "${local.bucket_arn.airflow}/*",
      ]
    }
  }
}
