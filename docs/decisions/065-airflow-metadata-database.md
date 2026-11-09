# D-065 — Airflow Metadata Database

Status: Accepted
Date: 2026-11-09
Phase: specs/04-orchestration-airflow

## Context

Airflow keeps its state (DAG runs, task states, users) in a database; it supports PostgreSQL 14 to
18. The chart's production guide advises "an external database", "running on a dedicated machine or
leveraging a cloud provider's database service such as AWS RDS", and warns that the Postgres bundled
with the chart "lacks stability, monitoring and persistence features" and that "you might experience
data loss". The project runs two Postgres as plain StatefulSets: the source
([D-022](022-source-postgres.md)) and the Polaris catalog
([D-046](046-catalog-metadata-database.md)). D-022 rated CloudNativePG (an operator: a component that
manages Postgres on Kubernetes) the market standard, and a plain StatefulSet not a best practice.

Discarded: Amazon RDS for PostgreSQL. The chart guide names it, but it is a managed database, and
README §4 allows only network, storage and managed Kubernetes to change per cloud (principle 7).

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Its own Postgres StatefulSet, as Polaris has | Accepted practice: apart from the chart, as the guide asks, but not on a dedicated machine | Reuses the Polaris manifest | One pod and a 1 GiB EBS volume | Same pattern as D-022 and D-046 |
| B. A second database in the Polaris Postgres | Accepted practice: apart from the chart; Airflow and Polaris share one server | One user and one database added to the Polaris init script | No new pod or volume | Reuses D-046; a Polaris database failure also stops Airflow |
| C. CloudNativePG: an operator plus a `Cluster` object | Best practice: the market standard for Postgres on Kubernetes (D-022), with backups and failover | Two Applications (operator and `Cluster`); a new component to learn | An operator pod, a Postgres pod and a 1 GiB EBS volume | A different Postgres pattern from D-022 and D-046 |
| D. The chart's bundled Postgres | Against best practice: the chart guide warns of data loss | One chart value | One pod and a volume | Diverges from D-046 |

## Decision

- **Recommended:** C, by principle 1: the market standard for Postgres on Kubernetes, at the cost
  of one more component and a second Postgres pattern in the project.
- **Chosen:** A
- **Reason:** consistency with the source and Polaris Postgres (D-022, D-046): one Postgres pattern
  in the project and no extra component. It differs from the recommendation (best practice set
  aside for simplicity and consistency). Moving every Postgres to CloudNativePG is recorded as
  evolution 1 in [EVOLUTIONS.md](../../EVOLUTIONS.md).

## Sources

- [Chart 1.22.0: production guide (Database)](https://github.com/apache/airflow/blob/helm-chart/1.22.0/chart/docs/production-guide.rst)
- [Chart 1.22.0: `values.yaml` (bundled Postgres image `bitnamilegacy/postgresql`)](https://github.com/apache/airflow/blob/helm-chart/1.22.0/chart/values.yaml)
- [Airflow 3.4.0: set up a database backend (PostgreSQL 14 to 18)](https://github.com/apache/airflow/blob/3.4.0/airflow-core/docs/howto/set-up-database.rst)
- [CloudNativePG v1.30.1: overview](https://github.com/cloudnative-pg/cloudnative-pg/blob/v1.30.1/docs/src/index.md)
