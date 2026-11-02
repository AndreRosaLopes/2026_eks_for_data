# 02 — Transactional Ingestion: TPC-H in Postgres, Cursor and CDC: How to Verify

A source Postgres and a DuckDB service run on the phase 01 cluster, and Airbyte ingests the
transactional data into the S3 bronze bucket by date cursor and by CDC. Each step below is verified
on its own; the end-to-end verification proves the phase [Done When](plan.md#done-when).

## Prerequisites

- The [phase 01 prerequisites](../01-ingestion-airbyte-s3/README.md#prerequisites)

## Access

- **Repository files:** opened in the editor or on GitHub; no credentials needed.
- **Source Postgres password:** `POSTGRES_PASSWORD` in your local `.env`, sent to the cluster as the
  Secret `postgres-credentials` ([HOW_TO_RUN section 2](../../HOW_TO_RUN.md#2-services-with-argo-cd)).
  Recommended generation (32 hexadecimal characters):

  ```bash
  echo "POSTGRES_PASSWORD=$(openssl rand -hex 16)" >> .env
  ```

  To read it back from the cluster:

  ```bash
  kubectl -n postgres get secret postgres-credentials -o jsonpath='{.data.password}' | base64 -d
  ```

- **DuckDB Quack token:** `QUACK_TOKEN` in your local `.env`, sent to the cluster as the Secret
  `duckdb-credentials` ([HOW_TO_RUN section 2](../../HOW_TO_RUN.md#2-services-with-argo-cd)).
- **DuckDB UI, inside the DuckDB pod** (main path,
  [D-033](../../docs/decisions/033-duckdb-service-configuration.md)): nothing to install; the source
  Postgres is already attached as `source` and the bronze bucket is readable.

  ```bash
  kubectl -n duckdb port-forward deploy/duckdb 4213:4213
  ```

  Then open `http://localhost:4213`. The local port must be 4213: the UI accepts only requests from
  `http://localhost:4213`, and any other port fails with "Offset is outside the bounds of the
  DataView" (reload with Ctrl+Shift+R after fixing it).
- **DuckDB UI on your computer** (alternative, not verified in this phase): install the
  [DuckDB 2.0 CLI](https://duckdb.org/install/), forward the Quack port, and start the UI:

  ```bash
  kubectl -n duckdb port-forward svc/duckdb 9494:9494
  ```

  ```bash
  duckdb -ui
  ```

  In the UI, attach the server with the token from `.env`. `localhost` uses plain HTTP, and AWS
  queries such as `glob('s3://...')` run on your computer, not on the server:

  ```sql
  CREATE SECRET (TYPE quack, TOKEN '<QUACK_TOKEN>');
  ATTACH 'quack:localhost:9494' AS remote;
  ```

## Step Verification

### 02.01 — Roadmap and Architecture

1. Open the project `README.md`, section **2. Target Architecture**.
   - Expected result: the rows "Source database (simulated OLTP) | PostgreSQL" and
     "Data generation and exploration | DuckDB".
2. In the same file, section **3. Phases**, compare it with [plan.md](plan.md).
   - Expected result: 02 is **Transactional ingestion**, 03 is **Processing and transformation:**
     Trino and dbt, and 04 is **Orchestration:** Airflow.

### 02.02 — Source Database

1. Read the password from the cluster and compare it with `POSTGRES_PASSWORD` in your `.env`:

   ```bash
   kubectl -n postgres get secret postgres-credentials -o jsonpath='{.data.password}' | base64 -d
   ```

   - Expected result: the same value.
2. List the schemas of the `source` database:

   ```bash
   kubectl -n postgres exec postgres-0 -- psql -U postgres -d source -c '\dn'
   ```

   - Expected result: `oltp`, `public` and `tpch`.
3. Check logical replication:

   ```bash
   kubectl -n postgres exec postgres-0 -- psql -U postgres -d source -c 'SHOW wal_level'
   ```

   - Expected result: `logical`.

### 02.03 — DuckDB Service

1. Open the DuckDB UI inside the pod (see [Access](#access)):

   ```bash
   kubectl -n duckdb port-forward deploy/duckdb 4213:4213
   ```

   Then open `http://localhost:4213` (the local port must be 4213; see [Access](#access)).
   - Expected result: the DuckDB UI loads.
2. In a new cell, list the databases:

   ```sql
   FROM duckdb_databases();
   ```

   - Expected result: `source` among the databases.
3. List the schemas of the source Postgres:

   ```sql
   SELECT schema_name FROM source.information_schema.schemata;
   ```

   - Expected result: `oltp` and `tpch` among the schemas.

### 02.04 — TPC-H Generation

1. Open the DuckDB UI (see [Access](#access)), paste the whole
   [01-generate-tpch.sql](../../pipelines/tpch/01-generate-tpch.sql) into a cell, keep
   `SET VARIABLE sf = 1;` and run it.
   - Expected result: it ends without errors after about a minute, and the last query shows the row
     counts below.
2. Check the row counts (the last query of the script, or run it again on its own):

   ```sql
   SELECT 'orders' AS table_name, count(*) AS row_count FROM source.tpch.orders
   UNION ALL SELECT 'lineitem', count(*) FROM source.tpch.lineitem
   UNION ALL SELECT 'customer', count(*) FROM source.tpch.customer;
   ```

   - Expected result: orders 1,500,000; lineitem about 6,000,000; customer 150,000.

### 02.05 — OLTP Baseline

1. In the DuckDB UI, paste the whole [02-oltp-baseline.sql](../../pipelines/tpch/02-oltp-baseline.sql)
   into a cell, keep `SET VARIABLE cutoff = '1997-12-31';` and run it. Running it again resets
   `oltp`. The cutoff accepts any date from `'1992-01-01'` (first TPC-H order) to `'1998-08-02'`
   (last one, which loads every order and leaves none for the daily simulation).
   - Expected result: it ends without errors after about 1.5 minutes; the last query shows 1,366,377
     orders, the first in 2020 and the last on yesterday's date, and some thousands of open orders.
2. Check that the columns have no TPC-H prefix:

   ```sql
   DESCRIBE source.oltp.orders;
   ```

   - Expected result: `orderkey`, `custkey`, `orderstatus`, …, `comment`, `updated_at`.
3. Check the statuses: orders from the last 30 days are open (`O`), older ones closed (`F`):

   ```sql
   SELECT orderstatus, min(orderdate), max(orderdate), count(*)
   FROM source.oltp.orders GROUP BY orderstatus;
   ```

   - Expected result: `F` up to 30 days ago; `O` from 29 days ago to yesterday.

### 02.06 — Day Simulation

1. In the DuckDB UI, paste the whole [03-simulate-day.sql](../../pipelines/tpch/03-simulate-day.sql)
   into a cell and run it. Each run advances one day (nothing to edit; the amounts of dimension
   changes per day are the `SET VARIABLE` lines at the top).
   - Expected result: after about 1 minute, the summary shows `simulated_day` one day after the
     previous run, about 600 `new_orders`, open, partial and finished orders, and `customers` +20
     and `suppliers` +10 compared with the previous run; `partsupp` stays the same from the second
     run on (20 pairs back, 20 deleted).

## Teardown

- [02.01](01-roadmap-and-architecture/spec.md#teardown): not applicable
- [02.02](02-source-database/spec.md#teardown): covered by phase 01 Turn Off
- [02.03](03-duckdb-service/spec.md#teardown): covered by phase 01 Turn Off
- [02.04](04-tpch-generation/spec.md#teardown): the tables go with the Postgres volume
- [02.05](05-oltp-baseline/spec.md#teardown): `oltp` goes with the Postgres volume; rerunning the
  script resets it
- [02.06](06-day-simulation/spec.md#teardown): rerunning the 02.05 baseline resets the simulation
