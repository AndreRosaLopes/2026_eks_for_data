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
- A Spark image with the Iceberg and S3 jars, built locally and pushed to `ghcr.io`
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
- [D-051 — Spark Base Image](../../docs/decisions/051-spark-base-image.md)
- [D-052 — AWS SDK Jars in the Spark Image](../../docs/decisions/052-aws-sdk-jars.md)
- [D-053 — Location of the Spark Image Dockerfile](../../docs/decisions/053-spark-dockerfile-location.md)
- [D-054 — Spark Image Tag](../../docs/decisions/054-spark-image-tag.md)
- [D-055 — How the Spark Image Is Built and Published](../../docs/decisions/055-spark-image-build.md)
- [D-056 — Spark Namespace Layout](../../docs/decisions/056-spark-namespace-layout.md)
- [D-057 — How a Spark Job Run Is Started](../../docs/decisions/057-spark-job-run-start.md)
- [D-058 — How Spark Gets AWS Credentials to Read Bronze](../../docs/decisions/058-spark-s3a-credentials.md)

**Divergences resolved (principle 7):** README §2 listed Trino and/or Spark as processing engine and
dbt for transformation, and §3 listed phase 03 as Trino and dbt and phase 04 as Airflow only. Updated
in step 03.01. The BI row (§2, "dbt Charts") and the personas (§5) still mention dbt and Trino as
future tools.

## Steps

| # | Step | Status |
|---|---|---|
| 03.01 | Roadmap: README §2 (Spark; Iceberg and REST catalog) and §3 (phases 03 and 04) updated | Done |
| 03.02 | [Silver bucket and IRSA roles](02-silver-bucket-and-irsa/spec.md): silver bucket and IRSA roles for Spark and Polaris (Terraform) | In progress |
| 03.03 | [Spark image](03-spark-image/spec.md): Dockerfile, built locally and pushed to `ghcr.io` | In progress |
| 03.04 | [Spark Operator](04-spark-operator/spec.md) via Argo CD; a job reads bronze `orders` and prints counts | In progress |
| 03.05 | Catalog Postgres and Polaris via Argo CD; warehouse on `silver` | To do |
| 03.06 | Dedup job: bronze `orders` → Iceberg `silver.orders`; DuckDB reads it | To do |
