# D-022 — Source Postgres

Status: Accepted
Date: 2026-10-31
Phase: specs/02-transactional-ingestion

## Context

Phase 02 needs a transactional Postgres as the source of the Airbyte syncs (date cursor and CDC).
CDC requires logical replication (`wal_level=logical`).

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Amazon RDS for PostgreSQL (db.t4g.micro, 20 GB gp3), Terraform in `infra/aws/cluster`; `rds.logical_replication = 1` | Managed database outside the platform, like a real source | One module + parameter group + security group; password in Secrets Manager | US$ 0.016/h + US$ 0.115/GB-month; destroyed with the cluster | Azure Database for PostgreSQL and Cloud SQL as equivalents, so a different resource per cloud |
| B. CloudNativePG (CNCF Sandbox operator, v1.30.1) via Argo CD | Market standard for Postgres on Kubernetes; `wal_level=logical` by default | Operator + `Cluster` CRD: two applications | A pod + an EBS volume | Identical on all three clouds |
| C. Plain StatefulSet (official `postgres` image, `wal_level=logical` in arguments) via Argo CD | No operator: not a best practice for a database on Kubernetes | Simplest | A pod + an EBS volume | Identical on all three clouds |

## Decision

- **Recommended:** A, because it is a market standard and reproduces a transactional source outside
  the data platform, with no operator to install.
- **Chosen:** C
- **Reason:** portability (the same manifest on EKS, AKS and GKE, README §4) and cost (no managed
  database charge; it goes away with the cluster). It does not follow the principle priority order:
  best practice (A or B) is set aside for portability and cost.

## Sources

- [Airbyte: Postgres source](https://docs.airbyte.com/integrations/sources/postgres)
- [CloudNativePG: logical replication](https://cloudnative-pg.io/documentation/current/logical_replication/)
- [Amazon RDS for PostgreSQL pricing](https://aws.amazon.com/rds/postgresql/pricing/)
