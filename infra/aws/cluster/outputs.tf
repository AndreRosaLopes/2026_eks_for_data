output "vpc_id" {
  value = module.vpc.vpc_id
}

output "azs" {
  value = module.vpc.azs
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "bronze_bucket" {
  value = module.s3_bronze.s3_bucket_id
}

output "airbyte_bucket" {
  value = module.s3_airbyte.s3_bucket_id
}

output "airbyte_role_arn" {
  value = module.airbyte_irsa.arn
}

output "duckdb_role_arn" {
  value = module.duckdb_irsa.arn
}

output "silver_bucket" {
  value = module.s3_silver.s3_bucket_id
}

output "spark_role_arn" {
  value = module.spark_irsa.arn
}

output "polaris_role_arn" {
  value = module.polaris_irsa.arn
}

output "silver_data_role_arn" {
  value = aws_iam_role.silver_data.arn
}

output "airflow_logs_bucket" {
  value = module.s3_airflow.s3_bucket_id
}

output "airflow_role_arn" {
  value = module.airflow_irsa.arn
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region us-east-1"
}
