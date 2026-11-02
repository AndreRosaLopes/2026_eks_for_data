# 02 — Transactional Ingestion: TPC-H in Postgres, Cursor and CDC: Plan

Status: Approved

## Objective

Simulate a transactional database (TPC-H with event dates moved to the present) and ingest it with
Airbyte into the S3 bronze bucket in two ways: incremental by a date column, and incremental by CDC.
DuckDB generates the data and reads both the source Postgres and the Parquet files in bronze. The
phase is delivered as three labs: lab01 (API, from phase 01), lab02 (date cursor) and lab03 (CDC).

The infrastructure (source Postgres and DuckDB service) comes first, then the data: TPC-H, the OLTP
baseline and a daily simulation run by hand. Then registration dates, the Airbyte user and the CDC
preparation, and finally the two labs.

## Scope

- Source Postgres in the cluster, with logical replication (`wal_level=logical`) and two schemas:
  `tpch` (as generated) and `oltp` (the operational system)
- DuckDB as a permanent service in the cluster (Quack), reading the source Postgres and the bronze
  bucket (IRSA)
- TPC-H generated into `tpch`, an OLTP baseline in `oltp` (dates shifted, `updated_at` by trigger)
  and a daily simulation (facts: inserts and status updates; dimensions: inserts, updates and
  deletes of rows no order uses), as SQL scripts in `pipelines/tpch/` run by hand with the DuckDB CLI in the pod
- Registration dates (`created_at`) on `customer` and `supplier`
- A dedicated Airbyte user created by Postgres on first start, and a CDC script (publication and
  replication slot) with a WAL limit on the slot
- lab02 (date cursor) and lab03 (CDC), built in the Airbyte UI and not saved
  ([D-021](../../docs/decisions/021-airbyte-connection-ui-lab.md)), each writing to its own bronze
  path; lab01 reused from [phase 01](../01-ingestion-airbyte-s3/lab01-api-ingestion.md)

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
- [D-026 — Day Simulation Changes](../../docs/decisions/026-day-simulation-changes.md) (superseded by D-037)
- [D-027 — Pipeline Scripts: Location and Execution](../../docs/decisions/027-pipeline-scripts.md) (superseded by D-043)
- [D-028 — Lab02 Cursor](../../docs/decisions/028-lab02-cursor.md)
- [D-029 — OLTP Write Method and Deletes](../../docs/decisions/029-oltp-write-method.md)
- [D-035 — SCD Type 2 Customer Changes](../../docs/decisions/035-scd2-customer-changes.md) (superseded by D-037)
- [D-037 — Day Simulation by Table Type](../../docs/decisions/037-day-simulation-by-table-type.md) (superseded by D-038)
- [D-038 — Day Simulation with Part-Supplier Insert](../../docs/decisions/038-day-simulation-with-partsupp-insert.md)
- [D-034 — Registration Dates](../../docs/decisions/034-registration-dates.md)
- [D-036 — Airbyte Database User](../../docs/decisions/036-airbyte-database-user.md)
- [D-039 — CDC Publication and Slot Script](../../docs/decisions/039-cdc-publication-and-slot-script.md)
- [D-040 — CDC Publication and Replica Identity](../../docs/decisions/040-cdc-publication-and-replica-identity.md)
- [D-041 — Replication Slot WAL Limit](../../docs/decisions/041-replication-slot-wal-limit.md)
- [D-042 — Lab Bronze Layout](../../docs/decisions/042-lab-bronze-layout.md)
- [D-043 — Pipeline Script Execution](../../docs/decisions/043-pipeline-script-execution.md)

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
| 02.06 | Day simulation: one daily script (facts: inserts and status updates; dimensions: inserts, updates, deletes), run by hand with the DuckDB CLI | Done |
| 02.07 | [Registration dates](07-registration-dates/spec.md): `created_at` on `customer` and `supplier` in the baseline and the day simulation | Done |
| 02.08 | [Airbyte user and CDC preparation](08-airbyte-user-and-cdc-preparation/spec.md): `AIRBYTE_PG_PASSWORD` from `.env` to the Secret, user created on Postgres' first start, slot WAL limit, `04-cdc-setup.sql` (publication and slot) | Done |
| 02.09 | [Lab02 — date cursor](09-lab02-date-cursor/spec.md): sync, simulate a day, sync; DuckDB shows that day's changes, and no deletes, in `oltp_cursor` | Done |
| 02.10 | [Lab03 — CDC](10-lab03-cdc/spec.md): sync, simulate a day, sync; DuckDB shows inserts, updates and deletes in `oltp_cdc`; phase end-to-end walkthrough | In progress |
