# 04 — Orchestration: Airflow for Airbyte and Spark: Plan

Status: Approved

## Objective

Airflow runs on the cluster and orchestrates the pipeline end to end: one DAG run triggers the
Airbyte sync to bronze, waits for it, then runs the Spark dedup job into the Iceberg table. This
replaces the manual "Sync now" in Airbyte and the manual `kubectl apply` of D-057.

## Scope

- Apache Airflow 3.4.0 on the cluster via Argo CD, with the KubernetesExecutor
- Task logs in S3 (remote logging)
- Airflow's metadata database as its own Postgres StatefulSet
- A custom Airflow image with the Airbyte provider, built locally and pushed to `ghcr.io`
- DAGs in `pipelines/airflow/dags/`, read by Airflow from Git (`GitDagBundle`)
- One DAG that triggers an Airbyte sync, then runs the Spark dedup job

## Out of Scope

- Schedules: DAGs are triggered by hand
- High availability
- Saving Airbyte configuration as code (D-021 stands)
- Orchestrating lab03 (CDC), Trino and dbt
- Moving every Postgres to CloudNativePG ([EVOLUTIONS.md](../../EVOLUTIONS.md), evolution 1)
- Azure and GCP deployments

## Done When

- Airflow runs on the cluster, deployed by Argo CD; its UI opens through port-forward
- One DAG run triggers the lab02 Airbyte sync and waits until it succeeds
- The same run then starts the Spark dedup job, which ends `COMPLETED`
- After the run, the Iceberg table's row count equals the distinct `orderkey` count in bronze
- Each task's log can be read in the Airflow UI after its pod has ended
- The teardown removes every resource that incurs cost
- No secrets in the repository

## Decisions

- [D-063 — Airflow Version](../../docs/decisions/063-airflow-version.md)
- [D-064 — Airflow Executor](../../docs/decisions/064-airflow-executor.md)
- [D-065 — Airflow Metadata Database](../../docs/decisions/065-airflow-metadata-database.md)
- [D-066 — Airbyte Provider Installation](../../docs/decisions/066-airbyte-provider-installation.md)
- [D-067 — DAG Delivery](../../docs/decisions/067-dag-delivery.md)

**Divergence resolved (principle 7):** README §3 said the phase 04 steps were "to be defined";
step 04.01 updates that row from this plan.

## Steps

| # | Step | Status |
|---|---|---|
| 04.01 | Roadmap: README §3, the phase 04 row updated from this plan | To do |
| 04.02 | Airflow image: Dockerfile (Airflow 3.4.0 plus the Airbyte provider), built locally and pushed to `ghcr.io` | To do |
| 04.03 | Airflow via Argo CD: metadata Postgres, KubernetesExecutor, task logs in S3 (IAM role), DAGs from Git; UI through port-forward | To do |
| 04.04 | Spark DAG: Airflow runs the dedup job and waits until it completes | To do |
| 04.05 | Airbyte DAG and end to end: one DAG triggers the lab02 sync, then the dedup job; phase walkthrough | To do |

Left to the step specs: chart values, resource requests, the Airflow admin login, the S3 location
and IAM role for the logs, the RBAC that lets Airflow create `SparkApplication` objects, how the
Airbyte API credentials reach Airflow, and the DAG and task names.
