# D-046 — Catalog Metadata Database

Status: Accepted
Date: 2026-11-02
Phase: specs/03-processing-spark-iceberg

## Context

Polaris ([D-044](044-iceberg-rest-catalog-server.md)) stores the catalog (namespaces, tables and the
pointer to each table's current metadata file) in a relational database. If it is lost, the Iceberg
files remain in S3, but the catalog no longer knows which tables exist.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Its own Postgres StatefulSet, same pattern as the source Postgres, password from `.env` | One database per service; platform metadata apart from the simulated OLTP | Reuses a known manifest | One small pod and a 1–5 GiB EBS volume | [D-022](022-source-postgres.md), [D-031](031-source-postgres-password-from-env.md), [D-032](032-one-application-per-component.md) |
| B. A `catalog` database in the source Postgres | Platform metadata inside the "external" source system | No new pod | Least | Resetting the source volume (as in the 02.08 upgrade) would wipe the catalog |
| C. A Postgres bundled by a Helm chart | Charts warn it is not for production | One flag | Same as A | Not bundled by the Polaris chart (only Lakekeeper's bundles one) |

## Decision

- **Recommended:** A, because it is the market practice and keeps the catalog safe from source
  resets.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Apache Polaris: Relational JDBC metastore](https://polaris.apache.org/)
- [Lakekeeper chart values (bundled Postgres warning)](https://github.com/lakekeeper/lakekeeper-charts/blob/main/charts/lakekeeper/values.yaml)
