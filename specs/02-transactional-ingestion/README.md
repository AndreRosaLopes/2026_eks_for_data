[How to Run](../../HOW_TO_RUN.md) › 02 — Transactional Ingestion: [Run](HOW_TO_RUN.md) | **Verify**

# 02 — Transactional Ingestion: TPC-H in Postgres, Cursor and CDC: How to Verify

A source Postgres and a DuckDB service run on the phase 01 cluster, and Airbyte ingests the
transactional data into the S3 bronze bucket by date cursor and by CDC. Each step below is verified
on its own; the end-to-end verification proves the phase [Done When](plan.md#done-when).

## Prerequisites and Access

- [How to Run, 2. Prerequisites](../../HOW_TO_RUN.md#2-prerequisites)
- [How to Run, 4. Access](../../HOW_TO_RUN.md#4-access): source Postgres and DuckDB UI; the
  passwords come from `.env` ([How to Run, 3.2](../../HOW_TO_RUN.md#32-services-with-argo-cd))

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

1. Open the DuckDB UI ([How to Run, 4.6 DuckDB UI](../../HOW_TO_RUN.md#46-duckdb-ui)).
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

1. Run [1. Generate TPC-H](HOW_TO_RUN.md#1-generate-tpc-h), keeping `sf = 1`.
   - Expected result: it ends without errors after about a minute, and the last query shows the row
     counts below.
2. Check the row counts (the last query of the script, or run it on its own in the
   [DuckDB UI](../../HOW_TO_RUN.md#46-duckdb-ui)):

   ```sql
   SELECT 'orders' AS table_name, count(*) AS row_count FROM source.tpch.orders
   UNION ALL SELECT 'lineitem', count(*) FROM source.tpch.lineitem
   UNION ALL SELECT 'customer', count(*) FROM source.tpch.customer;
   ```

   - Expected result: orders 1,500,000; lineitem about 6,000,000; customer 150,000.

### 02.05 — OLTP Baseline

1. Run [2. OLTP Baseline](HOW_TO_RUN.md#2-oltp-baseline), keeping the cutoff `'1997-12-31'`.
   - Expected result: it ends without errors after about 1.5 minutes; the last query shows 1,366,377
     orders, the first in 2020 and the last on yesterday's date, and some thousands of open orders.
2. In the DuckDB UI, check that the columns have no TPC-H prefix:

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

1. Run [3. Simulate a Day](HOW_TO_RUN.md#3-simulate-a-day).
   - Expected result: after about 1 minute, the summary shows `simulated_day` one day after the
     previous run, about 600 `new_orders`, open, partial and finished orders, and `customers` +20
     and `suppliers` +10 compared with the previous run; `partsupp` stays the same from the second
     run on (20 pairs back, 20 deleted).

### 02.07 — Registration Dates

1. After [2. OLTP Baseline](HOW_TO_RUN.md#2-oltp-baseline) and one
   [3. Simulate a Day](HOW_TO_RUN.md#3-simulate-a-day), open the
   [DuckDB UI](../../HOW_TO_RUN.md#46-duckdb-ui) and run:

   ```sql
   SELECT 'customer' AS t, min(created_at), max(created_at), count(*) FROM source.oltp.customer
   UNION ALL
   SELECT 'supplier', min(created_at), max(created_at), count(*) FROM source.oltp.supplier;
   ```

   - Expected result: for both, `min` near 2020-11 and `max` = the latest simulated day; 150,020
     customers and 10,010 suppliers after one simulated day.

### 02.08 — Airbyte User and CDC Preparation

1. Run [4. CDC Setup](HOW_TO_RUN.md#4-cdc-setup).
   - Expected result: the summary lists `airbyte_slot` (`pgoutput, logical`) and the 8 `oltp`
     tables in `airbyte_publication`.
2. Open the [DuckDB UI](../../HOW_TO_RUN.md#46-duckdb-ui) and run each query in its own cell:

   ```sql
   FROM postgres_query('source', $$
   SELECT rolname, rolreplication, pg_has_role('airbyte', 'pg_read_all_data', 'MEMBER') AS reads_all
   FROM pg_roles WHERE rolname = 'airbyte'
   $$);
   ```

   - Expected result: `airbyte`, `true`, `true`.

   ```sql
   FROM postgres_query('source', 'SELECT slot_name, plugin FROM pg_replication_slots');
   ```

   - Expected result: `airbyte_slot`, `pgoutput`.

   ```sql
   FROM postgres_query('source', 'SELECT tablename FROM pg_publication_tables');
   ```

   - Expected result: the 8 `oltp` tables.

### 02.09 — Lab02: Date Cursor

Follow [Lab 02 — Date Cursor Ingestion](lab02-cursor-ingestion.md):

1. Sections 2 and 3 (source and destination).
   - Expected result: both connection tests pass.
2. Section 4 (connection and sync 1).
   - Expected result: **Succeeded**; in DuckDB, `bronze` = `postgres` for `orders` and `customer`.
3. Section 5 (simulate a day and sync 2) and section 6.
   - Expected result: **Succeeded**, with far fewer records than sync 1; two lines per table, the
     second with the day's changes only.
4. Section 7.
   - Expected result: `30` deleted customers still in bronze: the cursor does not capture deletes.

## Teardown

- [02.01](01-roadmap-and-architecture/spec.md#teardown): not applicable
- [02.02](02-source-database/spec.md#teardown): covered by [Turn Off](../../HOW_TO_RUN.md#51-turn-off)
- [02.03](03-duckdb-service/spec.md#teardown): covered by [Turn Off](../../HOW_TO_RUN.md#51-turn-off)
- [02.04](04-tpch-generation/spec.md#teardown): the tables go with the Postgres volume
- [02.05](05-oltp-baseline/spec.md#teardown): `oltp` goes with the Postgres volume; rerunning the
  script resets it
- [02.06](06-day-simulation/spec.md#teardown): rerunning the 02.05 baseline resets the simulation
- [02.07](07-registration-dates/spec.md#teardown): rerunning the 02.05 baseline recreates the column
- [02.08](08-airbyte-user-and-cdc-preparation/spec.md#teardown): drop the slot when lab03 is no longer used
- [02.09](09-lab02-date-cursor/spec.md#teardown): delete the Airbyte objects; the files go with the bucket
