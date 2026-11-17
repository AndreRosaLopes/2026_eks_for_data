output "bronze_bucket" {
  value = module.s3_bronze.s3_bucket_id
}

output "silver_bucket" {
  value = module.s3_silver.s3_bucket_id
}

output "airbyte_bucket" {
  value = module.s3_airbyte.s3_bucket_id
}

output "airflow_logs_bucket" {
  value = module.s3_airflow.s3_bucket_id
}

output "velero_bucket" {
  value = module.s3_velero.s3_bucket_id
}
