# Buckets that survive the cluster teardown; only the purge destroys them (D-077, D-082).
# infra/aws/cluster builds their names from the pattern eks-for-data-<name>-<account>.

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

# Cleaned data layer: Iceberg tables written by Spark, registered in Polaris (D-015, D-044)
module "s3_silver" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.17.0"

  bucket        = "${local.name}-silver-${data.aws_caller_identity.current.account_id}"
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

# Airflow task logs (remote logging), one bucket per platform component (D-064, D-072)
module "s3_airflow" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.17.0"

  bucket        = "${local.name}-airflow-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  attach_deny_insecure_transport_policy = true
}

# Velero backups of the database volumes (D-076, D-077)
module "s3_velero" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.17.0"

  bucket        = "${local.name}-velero-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  attach_deny_insecure_transport_policy = true
}
