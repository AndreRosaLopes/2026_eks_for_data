[How to Run](../../HOW_TO_RUN.md) › 02 — Transactional Ingestion: **Run** | [Verify](README.md)

# 02 — Transactional Ingestion: TPC-H in Postgres, Cursor and CDC: How to Run

What to execute in this phase, once the environment is up. The checks and expected results are in
[Verify](README.md).

## Prerequisites

- The environment up: [How to Run, 3.1 Bring Up](../../HOW_TO_RUN.md#31-bring-up); Argo CD shows
  `postgres` and `duckdb` **Synced** and **Healthy**.

The scripts in `pipelines/tpch/` run with the DuckDB CLI inside the DuckDB pod
([D-043](../../docs/decisions/043-pipeline-script-execution.md)), in the order below.
`MSYS_NO_PATHCONV=1` stops Git Bash from rewriting `/duckdb` into a Windows path. To explore the
data, use the [DuckDB UI](../../HOW_TO_RUN.md#46-duckdb-ui).

## 1. Generate TPC-H

[01-generate-tpch.sql](../../pipelines/tpch/01-generate-tpch.sql) writes TPC-H into the `tpch`
schema (about 1 minute). The scale factor is the line `SET VARIABLE sf = 1;` in the file. Running it
again replaces the tables. Sections 1 and 2, with their expected results, form
[Lab 00 — TPC-H Generation](lab00-tpch-generation.md).

```bash
MSYS_NO_PATHCONV=1 kubectl -n duckdb exec -i deploy/duckdb -- /duckdb < pipelines/tpch/01-generate-tpch.sql
```

## 2. OLTP Baseline

[02-oltp-baseline.sql](../../pipelines/tpch/02-oltp-baseline.sql) builds the `oltp` schema from
`tpch`, with dates shifted so the cutoff becomes yesterday (about 2 minutes). The cutoff is the line
`SET VARIABLE cutoff = '1997-12-31';` in the file; it accepts any date from `'1992-01-01'` (first
TPC-H order) to `'1998-08-02'` (last one, which loads every order and leaves none for the daily
simulation). Running it again resets `oltp`, and the simulation restarts from yesterday.

```bash
MSYS_NO_PATHCONV=1 kubectl -n duckdb exec -i deploy/duckdb -- /duckdb < pipelines/tpch/02-oltp-baseline.sql
```

## 3. Simulate a Day

[03-simulate-day.sql](../../pipelines/tpch/03-simulate-day.sql) advances `oltp` by one day (about 1
minute): new orders, line items shipping, and customer, supplier and part-supplier changes. Nothing
to edit; the amounts of dimension changes per day are the `SET VARIABLE` lines at the top. Run it
once per simulated day.

```bash
MSYS_NO_PATHCONV=1 kubectl -n duckdb exec -i deploy/duckdb -- /duckdb < pipelines/tpch/03-simulate-day.sql
```

## 4. CDC Setup

[04-cdc-setup.sql](../../pipelines/tpch/04-cdc-setup.sql) creates the publication (the 8 `oltp`
tables) and the replication slot `airbyte_slot` that Airbyte's CDC reads
([D-039](../../docs/decisions/039-cdc-publication-and-slot-script.md)). Run it before lab03 and
again after any rerun of [2. OLTP Baseline](#2-oltp-baseline), which drops the publication's
tables. It drops and recreates both, so it fails while Airbyte is connected to the slot: stop the
sync first. From then on, Postgres keeps WAL for the slot until Airbyte reads it (at most 2GB,
[D-041](../../docs/decisions/041-replication-slot-wal-limit.md)).

```bash
MSYS_NO_PATHCONV=1 kubectl -n duckdb exec -i deploy/duckdb -- /duckdb < pipelines/tpch/04-cdc-setup.sql
```

## 5. Lab 02 — Date Cursor

Follow [Lab 02 — Date Cursor Ingestion](lab02-cursor-ingestion.md): a connection created in the
Airbyte UI reads `oltp` incrementally by `updated_at` and writes Parquet to `oltp_cursor` in the
bronze bucket; after a simulated day, a second sync brings only that day's inserts and updates, and
no deletes. The configuration is not saved
([D-021](../../docs/decisions/021-airbyte-connection-ui-lab.md)): repeat the lab in every new
environment.

## 6. Lab 03 — CDC

Follow [Lab 03 — CDC Ingestion](lab03-cdc-ingestion.md): after [4. CDC Setup](#4-cdc-setup), a
connection created in the Airbyte UI reads `oltp` by CDC through the slot `airbyte_slot` and writes
Parquet to `oltp_cdc` in the bronze bucket; after a simulated day, a second sync brings that day's
inserts, updates and deletes. The configuration is not saved
([D-021](../../docs/decisions/021-airbyte-connection-ui-lab.md)): repeat the lab in every new
environment.
