# 04.04 — Spark DAG: Specification

Status: Approved
Phase: [04 — Orchestration: Airflow for Airbyte and Spark](../plan.md)

## Design

| Component | Configuration | ADR |
|---|---|---|
| DAG | `spark_dedup_orders` in `pipelines/airflow/dags/`, triggered by hand | [D-067](../../../docs/decisions/067-dag-delivery.md) |
| DAG parameters | `catalog`, `namespace` and `table`, with no default; given when the DAG is triggered | [D-060](../../../docs/decisions/060-polaris-catalog-creation.md) |
| Task | `SparkKubernetesOperator` in namespace `spark`, `deferrable=True` | [D-045](../../../docs/decisions/045-spark-on-kubernetes.md), [D-074](../../../docs/decisions/074-spark-task-deferrable.md) |
| Job definition | `pipelines/spark/dedup-orders.yaml` as `application_file`; its three arguments become `{{ params.catalog }}`, `{{ params.namespace }}` and `{{ params.table }}` | [D-073](../../../docs/decisions/073-spark-dag-job-definition.md) |
| Finding the YAML | The DAG's template folder is `pipelines/spark/` inside the Git checkout Airflow already holds | [D-067](../../../docs/decisions/067-dag-delivery.md) |
| Job cleanup | The finished `SparkApplication` is deleted by the operator (its default), so each run starts clean | [D-057](../../../docs/decisions/057-spark-job-run-start.md) |
| Kubernetes access | Airflow's own ServiceAccount inside the cluster, through a connection without credentials, defined as an environment variable in the chart | — |
| RBAC | A Role in namespace `spark` allowing `SparkApplication` objects and their status, and reading pods and their logs, bound to `airflow-worker-kubernetes` (task pods) and `airflow-triggerer` (the deferred wait) | — |
| Node consolidation | Annotation `karpenter.sh/do-not-disrupt: "true"` on Airflow task pods (chart `workers.kubernetes.podAnnotations`) and on the Spark driver and executors; never on the long-running Airflow components | [D-075](../../../docs/decisions/075-batch-pods-node-consolidation.md) |
| RBAC location | `platform/aws/airflow-spark-rbac.yaml`, synced by the root Application, like the `spark` namespace | [D-056](../../../docs/decisions/056-spark-namespace-layout.md) |
| Manual run (phase 03) | Phase 03 How to Run §6 fills in the three names with `sed` before `kubectl apply` | [D-073](../../../docs/decisions/073-spark-dag-job-definition.md) |

## Files

| File | Change |
|---|---|
| `pipelines/airflow/dags/spark_dedup_orders.py` | Create: the DAG |
| `pipelines/spark/dedup-orders.yaml` | Modify: the three arguments become `{{ params.* }}`; `do-not-disrupt` on driver and executors |
| `platform/aws/airflow-spark-rbac.yaml` | Create: Role and RoleBinding in `spark` |
| `platform/aws/airflow.yaml` | Modify: the in-cluster Kubernetes connection as an environment variable; `do-not-disrupt` on task pods |
| `specs/03-processing-spark-iceberg/HOW_TO_RUN.md` | Modify: §6, fill in the names with `sed` before `kubectl apply` |
| `specs/04-orchestration-airflow/HOW_TO_RUN.md` | Modify: how to trigger the Spark DAG with its parameters |
| `specs/04-orchestration-airflow/README.md` | Modify: 04.04 section, pointing to the spec's checks |
| `specs/04-orchestration-airflow/plan.md` | Modify: step status |

## Verification Plan

No manual check, following the user's decision in 04.03: the agent runs every check.

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | RBAC as intended | `kubectl auth can-i` as each ServiceAccount | Both can create `SparkApplication` objects and read pods in `spark`; neither can do so in `airflow` or `default` | Pass: both ServiceAccounts can create `SparkApplication` objects and get pods in `spark`; neither can create them in `airflow` or `default` (reading pods in `airflow` comes from the chart's own RBAC, needed by the KubernetesExecutor) |
| 2 | Automated | DAG loaded from Git | Airflow API: DAG `spark_dedup_orders` and import errors | DAG present; no import errors | Pass: version `ad642b9`; 0 import errors |
| 3 | Automated | Airflow runs the job | Trigger the DAG with the catalog, namespace and table of the 03.06 test, through the API | Run `success`; the `SparkApplication` it created ended `COMPLETED` | Fail (2026-11-09), fixes applied, to be rerun: run 1 failed with 403 on `sparkapplications/status` (added to the Role); run 2's task pod and the Spark driver were evicted by Auto Mode consolidation (`Evicted pod: Underutilized`), which led to D-075. The environment was turned off before the rerun |
| 4 | Automated | Task deferred | Task state history and task pods | The task passed through `deferred`; two short task pods (start and finish) | Pending |
| 5 | Automated | Table correct after the run | DuckDB: table row count vs. distinct `orderkey` in bronze | Equal | Pending |
| 6 | Automated | Task log kept | Airflow API: the task's log; the logs bucket | The log shows the driver's `silver ... rows=` line; the object is in S3 | Pending |
| 7 | Automated | Manual run still works | Phase 03 How to Run §6 command, as a server dry run | The rendered `SparkApplication` is accepted | Pending |
| 8 | Automated | No memory failures | Pod status and events in `airflow` and `spark` | No `OOMKilled` or `Evicted` (D-018) | Pending |
| 9 | Automated | No secrets in the repository | `git grep` for every secret in `.env` | No match | Pending |

## Teardown

No new resource incurs cost: each finished `SparkApplication` is deleted by the operator, and the
rest goes with the environment at [Turn Off](../../../HOW_TO_RUN.md#51-turn-off).
