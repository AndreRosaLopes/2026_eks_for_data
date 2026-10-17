# D-009 — Airbyte Internal Storage and Database

Status: Accepted
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

Airbyte (Helm chart v2, the only supported chart since v2.1.0) needs object storage for logs and
state, and a Postgres database. By default, the chart runs MinIO and Postgres in the cluster.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Chart defaults: Postgres + MinIO in the cluster | MinIO community in maintenance mode since Dec/2025, no new images (secondary sources); Airbyte recommends external object storage | Simplest | EBS only | Meets all requirements |
| B. S3 bucket for logs and state (IRSA) + chart Postgres (EBS gp3) | Follows Airbyte's storage recommendation; in-cluster database acceptable for learning | Medium | S3 in cents | Airbyte supports GCS and Azure Blob storage; Postgres is the same on all clouds |
| C. S3 + Amazon RDS for PostgreSQL | Production standard | Database password to manage, more resources | + RDS | Equivalent to Azure Database for PostgreSQL / Cloud SQL |

## Decision

- **Recommended:** B, because it avoids the unmaintained MinIO and follows Airbyte's storage
  recommendation without the cost and secret of RDS.
- **Chosen:** B
- **Reason:** follows the recommendation.

## Sources

- [Airbyte: storage](https://docs.airbyte.com/platform/deploying-airbyte/integrations/storage)
- [Airbyte: Helm chart V2](https://docs.airbyte.com/platform/deploying-airbyte/chart-v2-community)
- [MinIO ends active development](https://linuxiac.com/minio-ends-active-development/) (secondary source)
