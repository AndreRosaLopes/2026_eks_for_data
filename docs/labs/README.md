# Labs

Data engineering training on the platform in this repository: EKS, Karpenter, Argo CD, Terraform,
Pod Identity, Airbyte with a Postgres CDC source (TPC-H data), DuckDB, an S3 bronze layer, the
Spark Operator, Iceberg with the Polaris REST catalog, and Airflow.

> Delta Lake is not part of the platform yet; lab 3.15 requires adding it.

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

| # | Topic | Concept | Practice on this platform |
|---|---|---|---|
| 2.1 | Ingestion concepts | Batch vs. streaming, ELT (Extract, Load, Transform) vs. ETL, push vs. pull, the medallion architecture (bronze, silver, gold). | Map each concept to the platform's components (Airbyte, S3 bronze, Spark, Iceberg). |
| 2.2 | Airbyte architecture | Source, destination, connection, and the pods that run each sync (orchestrator, source, destination). Where state is stored. | Run a sync, watch its pods appear and finish, and find where its state is stored. |
| 2.3 | First connection in the UI | The files, formats and partitioning a connection creates in the destination. | Create a public API source to S3 bronze connection in the UI and look at the files it writes. |
| 2.4 | Sync modes | Full refresh (overwrite or append) vs. incremental (append or append + deduped), and the cursor. | Pick a cursor and see what each mode does with updates and deletes. |
| 2.5 | CDC (Change Data Capture) on Postgres | WAL (Write-Ahead Log), logical replication, publication, replication slot, `REPLICA IDENTITY`. | Set up the Postgres CDC source and inspect the `_ab_cdc_*` metadata columns in bronze. |
| 2.6 | Simulating a day of changes | How inserts, updates and deletes at the source reach bronze. | Run the day-simulation scripts (inserts, updates, deletes on TPC-H tables) and follow them into bronze. |
| 2.7 | Risks of a replication slot | A slot that is not consumed keeps WAL on disk; the slot's WAL limit protects the database. | Pause the sync and watch WAL pile up. Then see the slot's WAL limit and how to recover. |
| 2.8 | Schema evolution | Airbyte's schema-change policies. | Add, drop or rename a column at the source, see how Airbyte propagates it, and compare the policies. |
| 2.9 | Idempotency and reprocessing | Why bronze is append-only and versioned. | Reset a stream, resync it and find duplicates. |
| 2.10 | Exploring bronze with DuckDB | Querying files in place on S3, with no load step. | Query Parquet/JSONL on S3, count records, inspect CDC metadata. |
| 2.11 | Connections as code | UI vs. API vs. declarative configuration, and why it matters for reproducibility. | Compare a connection created in the UI with one defined through the API or declarative configuration. |
| 2.12 | Monitoring syncs | Logs, failures and retries of each sync. | Read the logs, sync duration and row count of each run. |
| 2.13 | CDC heartbeat | On a database with little traffic, WAL builds up because the replication slot does not advance. A heartbeat table that Airbyte keeps writing to fixes this. | Create an `airbyte_heartbeat` table, add it to the publication, set `heartbeat_action_query`, and compare WAL size with and without it. |
| 2.14 | TOAST columns | TOAST is how Postgres stores large values outside the row. With the default `REPLICA IDENTITY`, an unchanged TOAST value is left out of the WAL, so the CDC record arrives without it. | Update a row that has a large text column and see what reaches bronze. Then try `REPLICA IDENTITY FULL`. |
| 2.15 | Initial load vs. CDC | A large first snapshot can block streaming. Airbyte's WASS algorithm and the "Initial Load Timeout in Hours" setting (default 8) deal with this. | Lower the timeout and watch the snapshot split into several syncs. |
| 2.16 | Refreshes and generations | "Refresh and remove records" vs. "refresh and retain records", the `_airbyte_generation_id` column, and resumable full refresh with synthetic cursors. | Run both kinds of refresh, then look at the generation IDs in bronze. |
| 2.17 | Mappers and PII | Mappers transform each stream during the sync: hash, encrypt (RSA), rename fields, filter rows. PII (personally identifiable information) is data that identifies a person. Do not map a cursor or primary key field, and remember that hashing does not change data that is already loaded. | Hash `c_phone` in TPC-H `customer`, then see why the destination has to be cleared. |
| 2.18 | Connector Builder and low-code CDK | Build an API connector without code with the CDK (Connector Development Kit). Pagination can be offset, page number, cursor or header link. Errors are retried with exponential backoff, and the wait time can be read from a rate-limit header. | Build a connector for a public API that has pagination and rate limits. |
| 2.19 | Ingesting straight into Iceberg | Airbyte's S3 Data Lake destination writes Iceberg tables (REST, Glue or Nessie catalogs), with no Parquet-in-bronze step before Spark. | Compare it with the current bronze → Spark path. Check first whether Polaris is supported: the docs disagree. |
| 2.20 | Debezium by comparison | Debezium is the CDC engine inside Airbyte. Incremental snapshots run in chunks (DBLog watermarks), are started from a signaling table, and run alongside streaming. Exactly-once delivery depends on Kafka Connect. | Not applicable. |
| 2.21 | Data contracts | ODCS (Open Data Contract Standard) is a YAML file that defines a dataset's schema, quality rules, SLA and owner. A schema registry checks schema compatibility for each message. | Write an ODCS contract for `orders` and validate it with `datacontract lint`. |
| 2.22 | Delivery semantics | At-most-once, at-least-once and exactly-once delivery, and why bronze is designed for at-least-once. | Interrupt a sync, rerun it and count duplicate keys in bronze. |
| 2.23 | Late-arriving and out-of-order data | Event time vs. ingestion time, and why records can arrive late or out of order. | Compare `_ab_cdc_updated_at` with `_airbyte_extracted_at` in bronze. |
| 2.24 | Checkpointing and backpressure | How a sync saves its state while it runs, and what happens when it fails halfway. | Cancel a sync halfway and see where the next one resumes. |
| 2.25 | Event-driven file ingestion | S3 event notifications vs. polling for new files. | Not applicable. |
| 2.26 | Freshness and volume | Data observability: alerts when a sync is late or brings in too few rows. | Compare the last sync time and row count of each stream with an expected threshold. |

## 3. Transformations: Spark, Delta and Iceberg

| # | Lab | What the student does and learns |
|---|---|---|
| 3.01 | Bronze to silver, day by day | Write each day's rows of the 8 tables from the date-cursor bronze to silver Iceberg tables, choosing the day's rows by ingestion time (`_airbyte_extracted_at`) in two ways: a watermark read from silver, or a time interval passed to the job. Keep each key's last state of the day, trim text, and extract numbers with regex. Partition silver by batch and overwrite the batch on each run, so reruns are idempotent. Declare each table's schema and cast bronze to it. Organize the code in three ways, one lab each: metadata-driven (A), one script per table (B), per-table spec and shared module (C). Run 3 simulated days and two reruns. |
| 3.02 | Bronze to silver with dirty data | Same as 3.01, after inserting invalid rows at the source: regex and allowed-value checks on `name`, `phone`, `mktsegment`, `orderpriority`, ranges and dates. Rows that fail go to a quarantine table (`<table>_rejected`). |
| 3.03 | Spark fundamentals | Driver, executors, partitions, lazy evaluation, transformations vs. actions, DataFrame vs. SQL. |
| 3.04 | Spark on Kubernetes | Spark Operator, the `SparkApplication` resource, its driver and executor pods, the image, how job code is delivered, and S3A credentials. |
| 3.05 | Spark UI | Jobs, stages, tasks, the DAG (Directed Acyclic Graph) of each job, SQL plans, the shuffle, skew and spill. Reach it through `port-forward` and the History Server. |
| 3.06 | Performance | Partitioning, `repartition` vs. `coalesce`, broadcast joins, AQE (Adaptive Query Execution), caching, executor sizing. Compare runs before and after in the Spark UI. |
| 3.07 | Table formats | Why plain Parquet is not enough: ACID transactions, snapshots, metadata, manifests. |
| 3.08 | Iceberg and its catalog | Polaris REST catalog, namespaces and tables, the metadata tree (`metadata.json`, manifest list, manifests, data files). |
| 3.09 | Bronze to silver dedup | Keep the latest record per key from the CDC stream, handling deletes and ordering by `_ab_cdc_lsn`. |
| 3.10 | `MERGE INTO` (upsert) | SCD1 (Slowly Changing Dimension type 1, overwrite in place) with `MERGE INTO`. Then check idempotency by running the job twice. |
| 3.11 | SCD2 in Iceberg | Keep history with `valid_from`, `valid_to` and `is_current`, using the two-step pattern (close the current row, then insert the new one) or a single `MERGE` with a union. Test it with the simulated customer changes. |
| 3.12 | Time travel and rollback | `VERSION AS OF`, `TIMESTAMP AS OF`, `rollback_to_snapshot`, tags and branches. |
| 3.13 | Schema and partition evolution | Add a column, then change the partition spec without rewriting data (hidden partitioning). |
| 3.14 | Table maintenance | Small files, `rewrite_data_files` (compaction), `expire_snapshots`, `remove_orphan_files`. Copy-on-write vs. merge-on-read. |
| 3.15 | Delta Lake by comparison | Same SCD2 and `MERGE` in Delta. Compare the `_delta_log`, time travel, `OPTIMIZE`/Z-ORDER, `VACUUM`, catalogs, and what other engines can read each format. |
| 3.16 | Gold layer | Aggregates and a star schema (fact and dimension tables) built from TPC-H, then queried from DuckDB or another engine through the catalog. |
| 3.17 | Data quality | Checks for nulls, unique keys, referential integrity and row counts between layers. Fail the job when a check fails. |

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
