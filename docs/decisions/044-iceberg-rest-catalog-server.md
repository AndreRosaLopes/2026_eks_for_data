# D-044 — Iceberg REST Catalog Server

Status: Accepted
Date: 2026-11-02
Phase: specs/03-processing-spark-iceberg

## Context

Spark writes Iceberg tables to the silver bucket, and DuckDB reads them back. The Iceberg REST
catalog is a specification (an HTTP API), not a server: one implementation must be chosen. It must be
self-hosted on Kubernetes, so the same catalog runs on AWS, Azure and GCP (README §1). The catalog
does no processing: the engines (Spark, Trino, DuckDB) read and write the data; the catalog keeps the
list of tables and each table's current metadata file, and can vend storage credentials.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Apache Polaris 1.8.0 | Apache Software Foundation project, vendor-neutral; Snowflake Open Catalog and Dremio's catalog build on it; clients Spark, Trino, Flink, Dremio, StarRocks, Doris; listed in the DuckDB docs; 1.x API line | JVM (Quarkus) server, heavier; Helm chart; built-in OAuth client credentials; vends S3 credentials with a role ARN and STS | One pod plus the metadata database; the chart sets no resources (to be measured, [D-018](018-workload-resource-requests.md)) | Postgres through JDBC; multi-cloud |
| B. Lakekeeper 0.14.2 | Apache 2.0, led by one company (Vakamo); tested with Spark, Trino, StarRocks and PyIceberg; listed in the DuckDB docs; 0.x | Single Rust binary with a UI, lighter; Helm chart (bundles a Postgres "not recommended for production"); with IRSA, vends credentials by assuming a role with an external ID | Lighter pod plus the database | Postgres 15 or later only; multi-cloud |
| C. Project Nessie 0.109 | Its own docs call the Iceberg REST support experimental; not in DuckDB's catalog list | Adds Git-like branches the phase does not need | One pod plus storage | Experimental REST puts the DuckDB read-back at risk |

## Decision

- **Recommended:** A, because it is the ASF standard with the widest engine support (principle 1);
  B is simpler but ranks lower on best practices.
- **Chosen:** A
- **Reason:** follows the recommendation. Memory use was considered: neither project publishes
  sizing, and the difference does not change the node size, so it does not decide.

## Sources

- [Apache Polaris](https://polaris.apache.org/) and [release 1.8.0](https://github.com/apache/polaris/releases/tag/apache-polaris-1.8.0)
- [Polaris Helm chart values](https://github.com/apache/polaris/blob/main/helm/polaris/values.yaml)
- [Lakekeeper](https://github.com/lakekeeper/lakekeeper), [storage](https://docs.lakekeeper.io/docs/nightly/storage/), [S3 storage](https://docs.lakekeeper.io/docs/nightly/storage-s3/) and [chart values](https://github.com/lakekeeper/lakekeeper-charts/blob/main/charts/lakekeeper/values.yaml)
- [Project Nessie: Iceberg REST](https://projectnessie.org/guides/iceberg-rest/)
- [DuckDB: Iceberg REST catalogs](https://duckdb.org/docs/2.0/core_extensions/iceberg/catalogs.html)
