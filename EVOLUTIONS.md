# Evolutions

Improvements identified while building the project and left for later. Each one becomes an ADR and
its own steps when it is taken up.

## 1. Manage Every Postgres with CloudNativePG

Identified in phase 04, while choosing the Airflow metadata database (D-065).

**Today:** each component runs Postgres in its own way: the source and the Polaris catalog as plain
StatefulSets with init scripts ([D-022](docs/decisions/022-source-postgres.md),
[D-046](docs/decisions/046-catalog-metadata-database.md)), Airbyte with the Postgres bundled in its
chart ([D-009](docs/decisions/009-airbyte-internal-storage.md)), and Airflow with its own
StatefulSet (D-065).

**Evolution:** one CloudNativePG operator, the market standard for Postgres on Kubernetes, manages a
`Cluster` object per component:

| Component | What it needs | Decision to supersede |
|---|---|---|
| Source | Logical replication (on by default) and the `airbyte` user with the `replication` attribute | D-022 |
| Polaris catalog | Database `polaris`, its owner and schema `polaris_schema` | D-046 |
| Airbyte | External database in its chart (`global.database.type: external`); Postgres 17 or earlier | D-009 |
| Airflow | External database connection | D-065 |
| Metabase (future) | Postgres as its application database | — |

**Gains:**

- One pattern: a short `Cluster` per component, instead of hand-written StatefulSets and init
  scripts.
- Databases, users, roles and settings declared in Git.
- Replicas with automatic failover, backups to object storage and a metrics exporter, available
  when needed.
- The same on AWS, Azure and GCP: only the StorageClass changes.

**Costs:** one more component (the operator); migrating each component in its own step.

**Sources:**

- [CloudNativePG documentation](https://github.com/cloudnative-pg/cloudnative-pg/blob/v1.30.1/docs/src/index.md)
- [Airbyte: external database](https://docs.airbyte.com/platform/deploying-airbyte/integrations/database)
- [Airflow chart: production guide (database)](https://github.com/apache/airflow/blob/helm-chart/1.22.0/chart/docs/production-guide.rst)
