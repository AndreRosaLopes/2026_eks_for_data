[How to Run](../../HOW_TO_RUN.md) › 02 — Transactional Ingestion: **Run** | [Verify](README.md)

# 02 — Transactional Ingestion: TPC-H in Postgres, Cursor and CDC: How to Run

What to execute in this phase, once the environment is up. The checks and expected results are in
[Verify](README.md).

## Prerequisites

- The environment up: [How to Run, 3. Bring Up](../../HOW_TO_RUN.md#3-bring-up); Argo CD shows
  `postgres` and `duckdb` **Synced** and **Healthy**.

The scripts in `pipelines/tpch/` run with the DuckDB CLI inside the DuckDB pod
([D-043](../../docs/decisions/043-pipeline-script-execution.md)), in the order below.
`MSYS_NO_PATHCONV=1` stops Git Bash from rewriting `/duckdb` into a Windows path. To explore the
data, use the [DuckDB UI](../../HOW_TO_RUN.md#46-duckdb-ui).

## 1. Generate TPC-H

[01-generate-tpch.sql](../../pipelines/tpch/01-generate-tpch.sql) writes TPC-H into the `tpch`
schema (about 1 minute). The scale factor is the line `SET VARIABLE sf = 1;` in the file. Running it
again replaces the tables.

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
