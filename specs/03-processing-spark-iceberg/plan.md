# 03 — Processing: Spark and Iceberg: Plan

Status: Approved

## Objective

Spark on the cluster reads the Parquet files Airbyte wrote to bronze (lab02, `oltp_cursor/oltp/`),
deduplicates `orders` by key (the latest `updated_at` wins) and writes an Apache Iceberg table to a
new silver bucket, registered in a self-hosted Iceberg REST catalog. DuckDB reads the table back.
This replaces Trino and dbt in the roadmap and prepares phase 04, where Airflow triggers Airbyte and
Spark.

## Scope

- Silver bucket ([D-015](../../docs/decisions/015-data-lake-bucket-layout.md)), versioning off as
  bronze ([D-016](../../docs/decisions/016-bronze-bucket-versioning.md)); Iceberg keeps the table
  history
- IRSA roles for Spark and the catalog ([D-008](../../docs/decisions/008-pod-aws-identity.md))
- A Spark image with the Iceberg and S3 jars, published to `ghcr.io` by GitHub Actions
- Spark Operator via Argo CD; jobs as `SparkApplication` YAML, code from `pipelines/spark/`
- Apache Polaris as REST catalog, with its own Postgres, via Argo CD
- One PySpark job: bronze `orders` → Iceberg `silver.orders`

## Out of Scope

- Trino, dbt and Airflow (phase 04)
- Tables other than `orders`; the gold layer
- Catalog authentication beyond the minimum Polaris needs
- Azure and GCP deployments

## Done When

- A Spark job on the cluster reads the bronze Parquet files
- `silver.orders` exists as an Iceberg table in the REST catalog, with one row per `orderkey` (the
  latest `updated_at`)
- DuckDB reads `silver.orders` through the catalog; its count equals the distinct `orderkey` values
  in bronze
- The teardown removes every resource that incurs cost
- No secrets in the repository

## Decisions

- [D-044 — Iceberg REST Catalog Server](../../docs/decisions/044-iceberg-rest-catalog-server.md)
- [D-045 — How Spark Runs](../../docs/decisions/045-spark-on-kubernetes.md)
- [D-046 — Catalog Metadata Database](../../docs/decisions/046-catalog-metadata-database.md)
- [D-047 — Spark Dependencies](../../docs/decisions/047-spark-dependencies.md)
- [D-048 — Spark Job Code Delivery](../../docs/decisions/048-spark-job-code-delivery.md)
- [D-049 — Storage Credentials for Silver](../../docs/decisions/049-silver-storage-credentials.md)
- [D-050 — Spark Version](../../docs/decisions/050-spark-version.md)

**Divergences resolved (principle 7):** README §2 listed Trino and/or Spark as processing engine and
dbt for transformation, and §3 listed phase 03 as Trino and dbt and phase 04 as Airflow only. Updated
in step 03.01. The BI row (§2, "dbt Charts") and the personas (§5) still mention dbt and Trino as
future tools.

## Steps

| # | Step | Status |
|---|---|---|
| 03.01 | Roadmap: README §2 (Spark; Iceberg and REST catalog) and §3 (phases 03 and 04) updated | Done |
| 03.02 | [Silver bucket and IRSA roles](02-silver-bucket-and-irsa/spec.md): silver bucket and IRSA roles for Spark and Polaris (Terraform) | In progress |
| 03.03 | Spark image: Dockerfile and GitHub Actions workflow publishing to `ghcr.io` | To do |
| 03.04 | Spark Operator via Argo CD; a job reads bronze `orders` and prints counts | To do |
| 03.05 | Catalog Postgres and Polaris via Argo CD; warehouse on `silver` | To do |
| 03.06 | Dedup job: bronze `orders` → Iceberg `silver.orders`; DuckDB reads it | To do |
