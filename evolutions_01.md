# Evolution 01: DuckDB Scripts as Kubernetes Jobs

A Job in Git is the better practice, but the manifest alone does not remove the manual step: a Job
runs once each time someone creates it. The full practice has two parts: **the definition lives in
Git**, and **something automatic creates the Job** (an orchestrator or a schedule). This project
already does exactly this for Spark; DuckDB would follow the same model.

## 1. How Spark Already Works in This Project

| Part | Spark (exists today) | Role |
|---|---|---|
| Script in Git | `pipelines/spark/dedup_orders.py` | The code |
| Script → ConfigMap (a Kubernetes object holding files) | `pipelines/spark/kustomization.yaml` ([D-048](docs/decisions/048-spark-job-code-delivery.md)), synced by the Argo CD application `spark-jobs` | Puts the script inside the cluster, always equal to Git |
| Job template in Git | `pipelines/spark/dedup-orders.yaml`, a `SparkApplication` ([D-073](docs/decisions/073-spark-dag-job-definition.md)) | Defines the image, memory, CPU and arguments of **one run** |
| Who triggers it | Airflow DAG `pipelines/airflow/dags/spark_dedup_orders.py` with `SparkKubernetesOperator` ([D-074](docs/decisions/074-spark-task-deferrable.md)) | Creates the run on demand (button in the Airflow UI) or on a schedule, waits and records the result |

Argo CD syncs only the ConfigMap, never the run itself
([D-057](docs/decisions/057-spark-job-run-start.md)). Argo CD keeps the cluster equal to Git all the
time; a run is a one-time event, so if Argo CD managed it, it would recreate it on every sync.

## 2. The Same Model for DuckDB

| Part | DuckDB (proposal) |
|---|---|
| Scripts in Git | `pipelines/tpch/*.sql` (unchanged) |
| Scripts → ConfigMap | A `kustomization.yaml` in `pipelines/tpch` plus an Argo CD application, as in D-048 |
| Job template | A `Job` running the `duckdb/duckdb:2.0.0` image. It mounts the ConfigMap, runs `/duckdb < /scripts/<script>.sql`, and gets **its own memory** (e.g., 4Gi request = limit for the generation) plus the Postgres password from the existing Secret |
| Trigger | An Airflow DAG with `KubernetesJobOperator` (the operator that creates a Kubernetes `Job`; not verified in the installed provider version), started from the Airflow UI. `03-simulate-day.sql` could get a daily schedule |
| Small permanent DuckDB server | Stays only for exploration (UI and Quack), with a small request = limit |

## 3. What a Run Looks Like

1. You click "Trigger" on the DAG in Airflow (or the schedule fires).
2. Airflow creates the Job from the Git template.
3. The pod is `Pending`, and EKS Auto Mode creates a node with room for it.
4. DuckDB runs the script; the logs show up in Airflow.
5. The Job ends, Airflow marks the task as success or failure, and the pod's reservation disappears.
6. Auto Mode removes the empty node.

You never request memory by hand: the 4Gi is written once in the Git template, and each run asks
for it automatically.

## 4. What Changes in the Project

| Document | Change |
|---|---|
| [D-043](docs/decisions/043-pipeline-script-execution.md) (pipeline script execution) | Replaced by a new decision (ADR): scripts run as Jobs triggered by Airflow |
| [D-018](docs/decisions/018-workload-resource-requests.md) (resource requests) | Applies to the Job (4Gi request = limit) and to the server (small request = limit) |
| Labs and `HOW_TO_RUN.md` | `kubectl exec ... < script.sql` becomes "trigger the DAG in Airflow" |

This is a planning-level change (a new decision plus a few steps), so it fits the project's
process: `/sdd-plan` or `/sdd-spec`.
