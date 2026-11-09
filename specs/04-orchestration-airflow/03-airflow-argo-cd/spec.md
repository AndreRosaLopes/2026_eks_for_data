# 04.03 — Airflow via Argo CD: Specification

Status: Approved
Phase: [04 — Orchestration: Airflow for Airbyte and Spark](../plan.md)

## Design

| Component | Configuration | ADR |
|---|---|---|
| Namespace | `airflow`, holding Airflow and its Postgres | — |
| Metadata Postgres | StatefulSet `airflow-postgres`, image `postgres:18.6` (Airflow supports 14 to 18), 1 GiB EBS volume deleted with it | [D-065](../../../docs/decisions/065-airflow-metadata-database.md) |
| Database user | `airflow`, owner of database `airflow` only, created by an init script, as for Polaris | [D-061](../../../docs/decisions/061-polaris-database-user.md) |
| Postgres Application | Argo CD Application `airflow-postgres` → `platform/aws/airflow-postgres/` | [D-032](../../../docs/decisions/032-one-application-per-component.md) |
| Airflow Application | Argo CD Application `airflow`: chart `airflow` 1.22.0 from `https://airflow.apache.org` | [D-063](../../../docs/decisions/063-airflow-version.md) |
| Image | `ghcr.io/andrerosalopes/airflow:3.4.0-airbyte6.2.0` | [D-066](../../../docs/decisions/066-airbyte-provider-installation.md) |
| Executor | `KubernetesExecutor`; Redis is not deployed (the chart deploys it only with Celery) | [D-064](../../../docs/decisions/064-airflow-executor.md) |
| Metadata connection | Chart's bundled Postgres off; connection from Secret `airflow-metadata` | [D-065](../../../docs/decisions/065-airflow-metadata-database.md) |
| Static keys | Fernet key, API secret key and JWT secret from Secrets created from `.env`, as the chart production guide advises | [D-031](../../../docs/decisions/031-source-postgres-password-from-env.md) |
| Argo CD hooks | `migrateDatabaseJob` and `createUserJob` with `useHelmHooks: false`; the migration Job runs on every Argo CD sync, as the chart docs instruct for Argo CD | [D-007](../../../docs/decisions/007-argo-cd-installation.md) |
| Admin login | FAB; `createUserJob` with user `admin` and the password from Secret `airflow-admin` | [D-071](../../../docs/decisions/071-airflow-admin-login.md) |
| DAGs | `GitDagBundle`: this public repository, folder `pipelines/airflow/dags`, branch `main` | [D-067](../../../docs/decisions/067-dag-delivery.md) |
| Task logs | Remote logging to `s3://eks-for-data-airflow-283429977024/logs` | [D-072](../../../docs/decisions/072-airflow-task-log-location.md) |
| Logs bucket | `eks-for-data-airflow-283429977024` in `infra/aws/cluster`, `force_destroy`, like silver | [D-072](../../../docs/decisions/072-airflow-task-log-location.md) |
| Logs IAM role | `eks-for-data-airflow`, read and write on that bucket only; trusts ServiceAccounts `airflow-worker`, `airflow-api-server` and `airflow-triggerer` in `airflow` | [D-008](../../../docs/decisions/008-pod-aws-identity.md) |
| Resources | Chart defaults, measured first | [D-018](../../../docs/decisions/018-workload-resource-requests.md) |
| Test DAG | `smoke_test`: one task that prints a line, to check scheduling and logs | — |
| UI access | `kubectl port-forward` to Service `airflow-api-server`, port 8080 | [D-012](../../../docs/decisions/012-cluster-and-ui-access.md) |

## Files

| File | Change |
|---|---|
| `infra/aws/cluster/storage.tf` | Modify: the logs bucket and the IRSA role |
| `infra/aws/cluster/outputs.tf` | Modify: `airflow_logs_bucket` and `airflow_role_arn` |
| `platform/aws/airflow-postgres.yaml` | Create: Application for the metadata Postgres |
| `platform/aws/airflow-postgres/airflow-postgres.yaml` | Create: namespace, init script, Service and StatefulSet |
| `platform/aws/airflow.yaml` | Create: Application for the Airflow chart |
| `pipelines/airflow/dags/smoke_test.py` | Create: the test DAG |
| `HOW_TO_RUN.md` | Modify: §3.2 Airflow passwords, keys and Secrets; §4 Airflow UI access; §5.1 Turn Off table |
| `specs/04-orchestration-airflow/HOW_TO_RUN.md` | Modify: how to run the test DAG |
| `specs/04-orchestration-airflow/README.md` | Modify: 04.03 section, pointing to the spec's checks |
| `specs/04-orchestration-airflow/plan.md` | Modify: step status |

## Verification Plan

No manual check, by the user's decision: the agent runs every check. Check 1's `apply` waits for
the user's confirmation, because it creates AWS resources.

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | Terraform adds only the bucket and role | `terraform plan`; after the user confirms, `terraform apply` in `infra/aws/cluster` | Only additions, no change or destroy; apply succeeds | Pending |
| 2 | Automated | Applications synced | `kubectl -n argocd get applications`; `kubectl -n airflow get pods` | `airflow-postgres` and `airflow` Synced and Healthy; scheduler, API server, DAG processor and triggerer Running | Pending |
| 3 | Automated | Database migrated and admin created | Migration and user Job status; `airflow users list` | Both Jobs completed; user `admin` listed | Pending |
| 4 | Automated | Admin Job safe to rerun | Run the user Job again | It completes without error; still one `admin` | Pending |
| 5 | Automated | Admin login works | Port-forward; `POST /auth/token` with `admin` and the `.env` password; then the UI opened through the Chrome extension | A token is issued; the UI lists DAG `smoke_test` | Pending |
| 6 | Automated | DAG read from Git | Airflow API: DAG `smoke_test` and its bundle | DAG present, from the Git bundle, with the commit as its version | Pending |
| 7 | Automated | Task runs in its own pod | Trigger `smoke_test`; watch pods in `airflow` | A task pod starts and ends; the run is `success` | Pending |
| 8 | Automated | Log kept in S3 | List the logs bucket | The task log object exists under `logs/` | Pending |
| 9 | Automated | Log readable after the pod ended | Airflow API: the task's log, after its pod is gone | The printed line is returned, read from S3 | Pending |
| 10 | Automated | No memory failures | Pod status and events in `airflow` | No `OOMKilled` or `Evicted` (D-018) | Pending |
| 11 | Automated | No secrets in the repository | `git grep` for every secret in `.env` | No match | Pending |

## Teardown

- The bucket (emptied by `force_destroy`) and the role go with
  `terraform -chdir=infra/aws/cluster destroy` at [Turn Off](../../../HOW_TO_RUN.md#51-turn-off).
- Airflow, its Postgres and the EBS volume go with the environment at Turn Off.
