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

## Teardown

- [02.01](01-roadmap-and-architecture/spec.md#teardown): not applicable
- [02.02](02-source-database/spec.md#teardown): covered by [Turn Off](../../HOW_TO_RUN.md#51-turn-off)
- [02.03](03-duckdb-service/spec.md#teardown): covered by [Turn Off](../../HOW_TO_RUN.md#51-turn-off)
- [02.04](04-tpch-generation/spec.md#teardown): the tables go with the Postgres volume
- [02.05](05-oltp-baseline/spec.md#teardown): `oltp` goes with the Postgres volume; rerunning the
  script resets it
- [02.06](06-day-simulation/spec.md#teardown): rerunning the 02.05 baseline resets the simulation
