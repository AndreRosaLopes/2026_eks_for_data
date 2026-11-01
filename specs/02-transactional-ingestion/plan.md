# 02 — Transactional Ingestion: TPC-H in Postgres, Cursor and CDC: Plan

Status: Approved (steps 02.01 to 02.06; steps 02.07 onward are planned later)

## Objective

Simulate a transactional database (TPC-H with event dates moved to the present) and ingest it with
Airbyte into the S3 bronze bucket in two ways: incremental by a date column, and incremental by CDC.
DuckDB generates the data and reads both the source Postgres and the Parquet files in bronze. The
phase is delivered as three labs: lab01 (API, from phase 01), lab02 (date cursor) and lab03 (CDC).

The infrastructure (source Postgres and DuckDB service) comes first, then the data: TPC-H, the OLTP
baseline and a daily simulation run by hand. CDC preparation and the labs are planned later.

## Scope

- Source Postgres in the cluster, with logical replication (`wal_level=logical`) and two schemas:
  `tpch` (as generated) and `oltp` (the operational system)
- DuckDB as a permanent service in the cluster (Quack), reading the source Postgres and the bronze
  bucket (IRSA)
- TPC-H generated into `tpch`, an OLTP baseline in `oltp` (dates shifted, `updated_at` by trigger)
  and a daily simulation (inserts, updates, deletes) plus a customer change script, as SQL scripts in
  `pipelines/tpch/` run by hand in the DuckDB UI
- Later steps (not planned yet): CDC preparation, lab02 and lab03, built in the Airbyte UI and not
  saved ([D-021](../../docs/decisions/021-airbyte-connection-ui-lab.md)); lab01 reused from
  [phase 01](../01-ingestion-airbyte-s3/lab01-api-ingestion.md)

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
- [D-030 — Source Postgres Password](../../docs/decisions/030-source-postgres-password.md) (superseded by D-031)
- [D-031 — Source Postgres Password from `.env`](../../docs/decisions/031-source-postgres-password-from-env.md)
- [D-032 — One Argo CD Application per Component](../../docs/decisions/032-one-application-per-component.md)
- [D-033 — DuckDB Service Configuration](../../docs/decisions/033-duckdb-service-configuration.md)
- [D-024 — TPC-H Dataset and Scale](../../docs/decisions/024-tpch-dataset-and-scale.md)
- [D-025 — Event Date Control](../../docs/decisions/025-event-date-control.md)
- [D-026 — Day Simulation Changes](../../docs/decisions/026-day-simulation-changes.md)
- [D-027 — Pipeline Scripts: Location and Execution](../../docs/decisions/027-pipeline-scripts.md)
- [D-028 — Lab02 Cursor](../../docs/decisions/028-lab02-cursor.md)
- [D-029 — OLTP Write Method and Deletes](../../docs/decisions/029-oltp-write-method.md)
- [D-035 — SCD Type 2 Customer Changes](../../docs/decisions/035-scd2-customer-changes.md)

## Open Points

To be answered when steps 02.07 onward are planned:

1. D-034: customer start date (ingestion date as the start date, compared against a baseline).
2. D-036: database user for Airbyte (dedicated user with `REPLICATION`, or `postgres`).

**Divergences resolved in step 02.01 (principle 7):** README §3 listed phase 02 as Trino and dbt
(this phase became 02; Trino/dbt 03; Airflow 04), and README §2 did not list DuckDB or a source
database.

## Steps

| # | Step | Status |
|---|---|---|
| 02.01 | Roadmap and architecture: README §2 and §3 updated | Done |
| 02.02 | Source database: Postgres StatefulSet with logical replication and schemas `tpch` and `oltp`, reachable from Airbyte and DuckDB | Done |
| 02.03 | DuckDB service: Quack via Argo CD; IRSA to read bronze; attaches the source Postgres | Done |
| 02.04 | TPC-H generation: DuckDB `dbgen` writes TPC-H (scale factor as a parameter) into `tpch` | Done |
| 02.05 | OLTP baseline: `oltp` tables with keys, `updated_at` and trigger; reference tables in full; orders and line items shifted up to load day − 1 | Done |
| 02.06 | Day simulation: daily script (inserts, closings, cancellations) and customer change script, run by hand in the DuckDB UI | To do |
| 02.07+ | CDC preparation, labs 02 and 03 | Not planned yet |
