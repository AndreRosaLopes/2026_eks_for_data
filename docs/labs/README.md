# Labs

Data engineering training on the platform in this repository: EKS, Karpenter, Argo CD, Terraform,
Pod Identity, Airbyte with a Postgres CDC source (TPC-H data), DuckDB, an S3 bronze layer, the
Spark Operator, Iceberg with the Polaris REST catalog, and Airflow.

> Delta Lake is not part of the platform yet; lab 3.13 requires adding it.

## 1. Infrastructure: learn Kubernetes

| # | Lab | What the student does and learns |
|---|---|---|
| 1.1 | Platform tour | Read the architecture, then map AWS (VPC, EKS, S3, RDS) to Kubernetes objects. Look at what Terraform created and what Argo CD created. |
| 1.2 | `kubectl` basics | Contexts, namespaces, `get`/`describe`/`logs`/`exec`, `-o yaml`, labels and selectors. |
| 1.3 | Workload objects | Pod, Deployment, ReplicaSet, StatefulSet, Job, CronJob. Delete a pod and watch it come back (self-healing). |
| 1.4 | Networking | Service (ClusterIP), DNS between namespaces, `port-forward` to reach the UIs, Ingress or Load Balancer. |
| 1.5 | Configuration and secrets | ConfigMap, Secret, environment variables and mounted volumes. Why secrets stay out of Git. |
| 1.6 | Storage | PersistentVolume, PersistentVolumeClaim, StorageClass (EBS). Why Postgres needs state and Spark does not. |
| 1.7 | Resources and scheduling | Requests and limits, QoS (Quality of Service) classes, OOMKilled, taints and tolerations, node affinity. |
| 1.8 | Autoscaling with Karpenter | Create a pending pod and watch a node appear. Then watch consolidation remove it, and see how `do-not-disrupt` protects Spark and Airflow pods. |
| 1.9 | AWS identity | Pod Identity: a ServiceAccount gets an IAM role, then the pod reads S3 with no access keys. Break the permission and read the `AccessDenied` error. |
| 1.10 | GitOps with Argo CD | Application, sync, drift, and self-heal: change something by hand and watch Argo CD revert it. Roll back through Git. |
| 1.11 | RBAC (Role-Based Access Control) | Role, RoleBinding, `kubectl auth can-i`, and the Airflow-to-SparkApplication case. |
| 1.12 | Troubleshooting | `CrashLoopBackOff`, `ImagePullBackOff`, `Pending`, events, `kubectl debug`. |
| 1.13 | Cost | Spot vs. On-Demand nodes, cost per node and namespace, and turning the lab off. |

## 2. Ingestion: Airbyte and its concepts

| # | Lab | What the student does and learns |
|---|---|---|
| 2.1 | Ingestion concepts | Batch vs. streaming, ELT (Extract, Load, Transform) vs. ETL, push vs. pull, the medallion architecture (bronze, silver, gold). |
| 2.2 | Airbyte architecture | Source, destination, connection, and the pods that run each sync (orchestrator, source, destination). Where state is stored. |
| 2.3 | First connection in the UI | Public API source to S3 bronze. Look at the files, formats and partitioning it creates. |
| 2.4 | Sync modes | Full refresh (overwrite or append) vs. incremental (append or append + deduped). Pick a cursor and see what each mode does with updates and deletes. |
| 2.5 | CDC (Change Data Capture) on Postgres | WAL (Write-Ahead Log), logical replication, publication, replication slot, `REPLICA IDENTITY`. The `_ab_cdc_*` metadata columns. |
| 2.6 | Simulating a day of changes | Run the day-simulation scripts (inserts, updates, deletes on TPC-H tables) and follow them into bronze. |
| 2.7 | Risks of a replication slot | Pause the sync and watch WAL pile up. Then see the slot's WAL limit and how to recover. |
| 2.8 | Schema evolution | Add, drop or rename a column at the source and see how Airbyte propagates it. Compare the schema-change policies. |
| 2.9 | Idempotency and reprocessing | Reset a stream, resync it, find duplicates, and see why bronze is append-only and versioned. |
| 2.10 | Exploring bronze with DuckDB | Query Parquet/JSONL on S3, count records, inspect CDC metadata. |
| 2.11 | Connections as code | UI vs. API vs. declarative configuration, and why it matters for reproducibility. |
| 2.12 | Monitoring syncs | Logs, failures, retries, and the sync duration and row count of each run. |

## 3. Transformations: Spark, Delta and Iceberg

| # | Lab | What the student does and learns |
|---|---|---|
| 3.1 | Spark fundamentals | Driver, executors, partitions, lazy evaluation, transformations vs. actions, DataFrame vs. SQL. |
| 3.2 | Spark on Kubernetes | Spark Operator, the `SparkApplication` resource, its driver and executor pods, the image, how job code is delivered, and S3A credentials. |
| 3.3 | Spark UI | Jobs, stages, tasks, the DAG (Directed Acyclic Graph) of each job, SQL plans, the shuffle, skew and spill. Reach it through `port-forward` and the History Server. |
| 3.4 | Performance | Partitioning, `repartition` vs. `coalesce`, broadcast joins, AQE (Adaptive Query Execution), caching, executor sizing. Compare runs before and after in the Spark UI. |
| 3.5 | Table formats | Why plain Parquet is not enough: ACID transactions, snapshots, metadata, manifests. |
| 3.6 | Iceberg and its catalog | Polaris REST catalog, namespaces and tables, the metadata tree (`metadata.json`, manifest list, manifests, data files). |
| 3.7 | Bronze to silver dedup | Keep the latest record per key from the CDC stream, handling deletes and ordering by `_ab_cdc_lsn`. |
| 3.8 | `MERGE INTO` (upsert) | SCD1 (Slowly Changing Dimension type 1, overwrite in place) with `MERGE INTO`. Then check idempotency by running the job twice. |
| 3.9 | SCD2 in Iceberg | Keep history with `valid_from`, `valid_to` and `is_current`, using the two-step pattern (close the current row, then insert the new one) or a single `MERGE` with a union. Test it with the simulated customer changes. |
| 3.10 | Time travel and rollback | `VERSION AS OF`, `TIMESTAMP AS OF`, `rollback_to_snapshot`, tags and branches. |
| 3.11 | Schema and partition evolution | Add a column, then change the partition spec without rewriting data (hidden partitioning). |
| 3.12 | Table maintenance | Small files, `rewrite_data_files` (compaction), `expire_snapshots`, `remove_orphan_files`. Copy-on-write vs. merge-on-read. |
| 3.13 | Delta Lake by comparison | Same SCD2 and `MERGE` in Delta. Compare the `_delta_log`, time travel, `OPTIMIZE`/Z-ORDER, `VACUUM`, catalogs, and what other engines can read each format. |
| 3.14 | Gold layer | Aggregates and a star schema (fact and dimension tables) built from TPC-H, then queried from DuckDB or another engine through the catalog. |
| 3.15 | Data quality | Checks for nulls, unique keys, referential integrity and row counts between layers. Fail the job when a check fails. |

## 4. Orchestration: Airflow

| # | Lab | What the student does and learns |
|---|---|---|
| 4.1 | Orchestration concepts | Scheduling vs. orchestration, dependencies, idempotency, backfill, SLA (Service Level Agreement). Why cron is not enough. |
| 4.2 | Airflow architecture | Scheduler, API server/webserver, DAG processor, triggerer, metadata database, executor (KubernetesExecutor: one pod per task). |
| 4.3 | First DAG | DAG, tasks, operators, the TaskFlow API, `>>` dependencies. How the DAG gets into Airflow (Git sync). |
| 4.4 | Scheduling and time | `schedule`, `logical_date`, data intervals, `catchup`, backfill, and templating with `{{ ds }}`. |
| 4.5 | Retries and failures | `retries`, `retry_delay`, timeouts, trigger rules, callbacks, marking tasks as success or failed, clearing tasks. |
| 4.6 | Triggering Spark from Airflow | Submit a `SparkApplication`, wait for its status, and check the RBAC it needs. Follow the task pod and the Spark pods. |
| 4.7 | Triggering Airbyte from Airflow | Start a sync through the API and wait for it to finish. |
| 4.8 | End-to-end pipeline | Airbyte sync, then bronze-to-silver dedup, SCD2, gold, and quality checks, all as one DAG. |
| 4.9 | Data-aware scheduling | Datasets/Assets: a DAG that runs when a table is updated, instead of on a fixed time. |
| 4.10 | Connections, variables and secrets | Connections, Variables, and a secrets backend. What must never go into the DAG code. |
| 4.11 | Sensors and deferrable operators | Poke vs. reschedule vs. deferrable, and the triggerer's role. |
| 4.12 | Operating Airflow | Task logs, pools, concurrency, priority, pausing DAGs, and Karpenter's impact on task pods. |
| 4.13 | Testing DAGs | Import tests, `dag.test()`, and validating DAGs before they are merged. |

## 5. Lab format

Every lab uses the same sections: **Goal, Prerequisites, Concepts, Steps, Validation (expected
result), Break it (a controlled failure to diagnose), Questions, Cleanup.**
