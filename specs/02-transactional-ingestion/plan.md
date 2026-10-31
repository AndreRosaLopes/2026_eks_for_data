# 02 — Transactional Ingestion: TPC-H in Postgres, Cursor and CDC: Plan

Status: Approved (steps 02.01 to 02.03; steps 02.04 onward are planned later)

## Objective

Simulate a transactional database (TPC-H with event dates moved to the present) and ingest it with
Airbyte into the S3 bronze bucket in two ways: incremental by a date column, and incremental by CDC.
DuckDB generates the data and reads both the source Postgres and the Parquet files in bronze. The
phase is delivered as three labs: lab01 (API, from phase 01), lab02 (date cursor) and lab03 (CDC).

The infrastructure (source Postgres and DuckDB service) comes first. The data and script steps are
planned once it is running.

## Scope

- Source Postgres in the cluster, with logical replication (`wal_level=logical`) and two schemas:
  `tpch` (as generated) and `oltp` (the operational system)
- DuckDB as a permanent service in the cluster (Quack), reading the source Postgres and the bronze
  bucket (IRSA)
- Later steps (not planned yet): TPC-H load, day simulation, CDC preparation, lab02 and lab03, built
  in the Airbyte UI and not saved ([D-021](../../docs/decisions/021-airbyte-connection-ui-lab.md));
  lab01 reused from [phase 01](../01-ingestion-airbyte-s3/lab01-api-ingestion.md)

## Out of Scope

- Trino, dbt, Airflow
- Saving the Airbyte configuration (D-021)
- Sync scheduling
- Azure and GCP deployments
- High availability and backups of the source database
- Deduplication: the Airbyte S3 destination does not support "Incremental Append + Deduped", so the
  labs use "Incremental Append"

## Done When

- Following the phase README, the source Postgres and the DuckDB service come up on the phase 01
  environment
- DuckDB reads the source Postgres and the Parquet files in bronze
- lab02: after a simulated day, an incremental sync by date column brings that day's changes into
  bronze
- lab03: after a simulated day, a CDC sync brings that day's inserts, updates and deletes into bronze
- The teardown removes every resource that incurs cost
- No secrets in the repository

## Decisions

- [D-022 — Source Postgres](../../docs/decisions/022-source-postgres.md)
- [D-023 — DuckDB as a Service](../../docs/decisions/023-duckdb-service.md)
- [D-030 — Source Postgres Password](../../docs/decisions/030-source-postgres-password.md)

Answered, recorded as ADRs when steps 02.04 onward are planned:

| # | Decision | Answer |
|---|---|---|
| D-024 | Dataset and scale | TPC-H; scale factor as a parameter, SF0.1 or SF1 (size resources for SF1) |
| D-025 | Event date control | Dates shifted once at load time (latest = load day − 1), only in `oltp`; each load takes a date range (`from`, `to`), so the daily inserts come from TPC-H; reference tables (`region`, `nation`, `supplier`, `part`, `partsupp`) use full refresh |
| D-028 | lab02 cursor | `updated_at` kept by a trigger |

## Open Points

To be answered when steps 02.04 onward are planned:

1. Customer start date: ingestion date as the start date, compared against a baseline.
2. Customers that never bought: used for SCD type 2 changes, through a script run by hand (details
   open).
3. D-026: which rows the simulation updates and deletes, and in which tables.
4. D-027: where the scripts and labs live, and how the scripts run.
5. D-029: write method (native Postgres SQL through `postgres_execute`, DuckDB SQL on the attached
   tables, or `psql`) and deletes (foreign key with `ON DELETE CASCADE` or explicit).

**Divergences resolved in step 02.01 (principle 7):** README §3 listed phase 02 as Trino and dbt
(this phase became 02; Trino/dbt 03; Airflow 04), and README §2 did not list DuckDB or a source
database.

## Steps

| # | Step | Status |
|---|---|---|
| 02.01 | Roadmap and architecture: README §2 and §3 updated | Done |
| 02.02 | Source database: Postgres StatefulSet with logical replication and schemas `tpch` and `oltp`, reachable from Airbyte and DuckDB | To do |
| 02.03 | DuckDB service: Quack via Argo CD; IRSA to read bronze; attaches the source Postgres | To do |
| 02.04+ | TPC-H load, day simulation, CDC preparation, labs 02 and 03 | Not planned yet |
