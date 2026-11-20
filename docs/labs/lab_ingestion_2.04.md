[Labs](README.md) › 2.04

# Lab 2.04 — Date Cursor Ingestion with Airbyte

## Goal

Create, in the Airbyte UI, a connection that reads the `oltp` schema of the source Postgres
incrementally by the `updated_at` column and writes Parquet files to the S3 bronze bucket. Then
simulate a day and sync again: only that day's inserts and updates arrive, **and deletes do not**.

## Prerequisites

1. [Lab 2.02 — OLTP Baseline and Day Simulation](lab_ingestion_2.02.md) done: `oltp` has the 8
   tables.
2. Airbyte, Postgres and DuckDB running, from the repository root in Git Bash:

   ```bash
   kubectl -n argocd get applications airbyte postgres duckdb
   ```

   Expected: the three `Synced` and `Healthy`.

3. The Airbyte UI open. Print the admin password:

   ```bash
   kubectl -n airbyte get secret airbyte-auth-secrets -o jsonpath='{.data.instance-admin-password}' | base64 -d; echo
   ```

   In a second Git Bash window, leave the tunnel running:

   ```bash
   kubectl -n airbyte port-forward svc/airbyte-airbyte-server-svc 8001:8001
   ```

   Open `http://localhost:8001`, enter your email, and sign in with the password printed above.

4. The DuckDB UI open. In a third Git Bash window, leave this loop running:

   ```bash
   while true; do kubectl -n duckdb port-forward deploy/duckdb 4213:4213; sleep 1; done
   ```

   Open `http://localhost:4213`. The local port must be 4213. The tunnel often drops
   (`lost connection to pod`): the loop reconnects it, then reload the page.

5. The password of the `airbyte` database user, for the source form:

   ```bash
   kubectl -n postgres get secret postgres-credentials -o jsonpath='{.data.airbyte-password}' | base64 -d; echo
   ```

   It is also `AIRBYTE_PG_PASSWORD` in `.env`. Never write it into a file in the repository.

If **Sources** already lists `Postgres oltp (cursor)`, the environment was restored from a backup
with this lab's objects: go to [step 5](#5-simulate-a-day-and-sync-2). The counts of step 4 apply
only to the first sync.

## Concepts

- **Airbyte:** the ingestion tool. It copies data from a **source** (here the source Postgres) to a
  **destination** (here the S3 bronze bucket). A **connection** links one source to one destination
  and lists the **streams** to copy; each stream is one table.
- **Sync:** one run of a connection. Airbyte starts pods for it (reading the source, writing the
  destination) and removes them at the end.
- **Bronze:** the first layer of the data lake: data as it arrived from the source, unchanged,
  appended on every sync.
- **Parquet:** a columnar file format, compressed and typed, that DuckDB and Spark read directly
  from S3.
- **Incremental | Append:** each sync reads only the rows changed since the last one and appends
  them to the destination, so a row changed twice appears twice in bronze.
- **Cursor:** the column that tells which rows changed. Here it is `updated_at`, which every `oltp`
  insert and update sets ([D-028](../decisions/028-lab02-cursor.md)). Airbyte stores the largest
  value it read and, on the next sync, reads only rows above it.
- **Why deletes are missed:** a deleted row no longer exists, so no query by cursor can find it.
- **No access keys:** the S3 destination has no access key; its pod uses an IAM role (AWS
  permissions given to the pod's Kubernetes service account).
- **Airbyte metadata columns:** Airbyte adds columns to each row, such as `_airbyte_extracted_at`,
  the time the sync read it.
- **Layout:** each lab writes to its own path in the bronze bucket, `oltp_cursor` here and
  `oltp_cdc` in lab 2.05, so the two methods can be compared table by table
  ([D-042](../decisions/042-lab-bronze-layout.md)).

## Steps

### 1. Source: Postgres, User-Defined Cursor

**Sources** → **New source** → **Postgres**:

| Field | Value |
|---|---|
| Source name | `Postgres oltp (cursor)` |
| Host | `postgres.postgres.svc.cluster.local` |
| Port | `5432` |
| Database Name | `source` |
| Username | `airbyte` |
| Password | The password printed in prerequisite 5 |
| SSL Mode | `disable` (the source Postgres has no TLS) |
| Schemas | `oltp` only (remove `public`) |
| Update Method | **Scan Changes with User Defined Cursor** |

**Set up source**. Expected: the connection test passes.

### 2. Destination: S3 Bronze, Parquet

**Destinations** → **New destination** → **S3**:

| Field | Value |
|---|---|
| Destination name | `S3 bronze oltp_cursor` |
| S3 Bucket Name | `eks-for-data-bronze-283429977024` |
| S3 Bucket Path | `oltp_cursor` |
| S3 Bucket Region | `us-east-1` |
| Output Format | **Parquet: Columnar Storage**, Compression Codec `SNAPPY` |
| Access Key ID, Secret Access Key, Role ARN | **Empty**: the connector uses the pod's IAM role |

**Set up destination**. Expected: the connection test passes.

### 3. Connection

**Connections** → **New connection** → source `Postgres oltp (cursor)` → destination
`S3 bronze oltp_cursor`:

| Field | Value |
|---|---|
| Streams | All 8 (`customer`, `lineitem`, `nation`, `orders`, `part`, `partsupp`, `region`, `supplier`), selected |
| Select Sync Mode | **Append Historical Changes** |
| Append mode | **Append new rows and updates only** (Incremental \| Append) for each stream |
| Cursor | `updated_at` for each stream |
| Primary key | As detected from the table |

Each stream shows **cursor missing** in red until its cursor is chosen: open the stream's
**Cursor** field and select `updated_at`. **Next** is enabled once all 8 streams have it.

Then **Next** → **Configure connection**:

| Field | Value |
|---|---|
| Schedule type | **Manual** |
| Destination Namespace | **Source-defined** (writes to `oltp_cursor/oltp/<table>/`) |
| Advanced settings: When the source schema changes, I want to | **Propagate field changes only** |
| Advanced settings: Be notified when schema changes occur | Off |
| Advanced settings: Backfill new or renamed columns | Off |

**Set up connection**.

### 4. Sync 1

**Sync now**. Expected: the sync ends as **Succeeded** after several minutes: it reads about 1.37
million orders and 6 million line items.

In the DuckDB UI, compare bronze with Postgres (`source.oltp`, the source Postgres attached in
DuckDB): the rows of each table and the latest cursor value (`max(updated_at)`):

```sql
WITH bronze AS (
  SELECT 'customer' AS t, count(*) AS bronze, max(updated_at) AS bronze_cursor FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cursor/oltp/customer/*.parquet')
  UNION ALL SELECT 'lineitem', count(*), max(updated_at) FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cursor/oltp/lineitem/*.parquet')
  UNION ALL SELECT 'nation', count(*), max(updated_at) FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cursor/oltp/nation/*.parquet')
  UNION ALL SELECT 'orders', count(*), max(updated_at) FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cursor/oltp/orders/*.parquet')
  UNION ALL SELECT 'part', count(*), max(updated_at) FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cursor/oltp/part/*.parquet')
  UNION ALL SELECT 'partsupp', count(*), max(updated_at) FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cursor/oltp/partsupp/*.parquet')
  UNION ALL SELECT 'region', count(*), max(updated_at) FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cursor/oltp/region/*.parquet')
  UNION ALL SELECT 'supplier', count(*), max(updated_at) FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cursor/oltp/supplier/*.parquet')
),
postgres AS (
  SELECT 'customer' AS t, count(*) AS postgres, max(updated_at) AS postgres_cursor FROM source.oltp.customer
  UNION ALL SELECT 'lineitem', count(*), max(updated_at) FROM source.oltp.lineitem
  UNION ALL SELECT 'nation', count(*), max(updated_at) FROM source.oltp.nation
  UNION ALL SELECT 'orders', count(*), max(updated_at) FROM source.oltp.orders
  UNION ALL SELECT 'part', count(*), max(updated_at) FROM source.oltp.part
  UNION ALL SELECT 'partsupp', count(*), max(updated_at) FROM source.oltp.partsupp
  UNION ALL SELECT 'region', count(*), max(updated_at) FROM source.oltp.region
  UNION ALL SELECT 'supplier', count(*), max(updated_at) FROM source.oltp.supplier
)
SELECT t, bronze, postgres, bronze_cursor, postgres_cursor
FROM bronze JOIN postgres USING (t)
ORDER BY t;
```

Expected: `bronze` = `postgres` and `bronze_cursor` = `postgres_cursor` for the 8 tables. The
cursor value is the time the baseline (or the last simulated day) wrote each table; Airbyte keeps
the largest one per stream and, on the next sync, reads only rows above it.

### 5. Simulate a Day and Sync 2

1. From the repository root (about 1 minute):

   ```bash
   MSYS_NO_PATHCONV=1 kubectl -n duckdb exec -i deploy/duckdb -- /duckdb < pipelines/tpch/03-simulate-day.sql
   ```

   Expected: the summary shows the next `simulated_day`.

2. In the Airbyte UI, open the connection → **Sync now**. Expected: **Succeeded**, with far fewer
   records than sync 1 (thousands, not millions).

3. In the DuckDB UI, compare the order date range in bronze and in Postgres:

   ```sql
   SELECT 'bronze' AS base, min(orderdate) AS first_order, max(orderdate) AS last_order
   FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cursor/oltp/orders/*.parquet')
   UNION ALL
   SELECT 'postgres', min(orderdate), max(orderdate) FROM source.oltp.orders;
   ```

   Expected: the same `first_order` and `last_order` in both; `last_order` is the simulated day.

4. In a new cell, compare the orders of the last 5 days in both:

   ```sql
   WITH last_day AS (SELECT max(orderdate) AS d FROM source.oltp.orders),
   bronze AS (
     SELECT orderdate, count(DISTINCT orderkey) AS bronze_orders
     FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cursor/oltp/orders/*.parquet'), last_day
     WHERE orderdate > d - 5
     GROUP BY orderdate
   ),
   postgres AS (
     SELECT orderdate, count(*) AS postgres_orders
     FROM source.oltp.orders, last_day
     WHERE orderdate > d - 5
     GROUP BY orderdate
   )
   SELECT orderdate, bronze_orders, postgres_orders
   FROM postgres LEFT JOIN bronze USING (orderdate)
   ORDER BY orderdate;
   ```

   Expected: 5 lines, `bronze_orders` = `postgres_orders` on each day; the last day is the
   simulated day, with about 600 orders. Bronze counts distinct `orderkey` because an order whose
   status changed has one row per sync. Run it before sync 2 to see the simulated day still
   missing from bronze, and again after each new simulated day and sync to follow the evolution.

## Validation

In the DuckDB UI, run each query in its own cell.

1. Each sync writes new files. Count the rows per file timestamp (one line per sync):

   ```sql
   SELECT regexp_extract(filename, '_(\d{10,13})_', 1) AS sync_epoch, count(*) AS rows
   FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cursor/oltp/orders/*.parquet', filename = true)
   GROUP BY ALL ORDER BY sync_epoch;
   ```

   Expected: one line per sync; the last one holds the day's new orders plus the orders whose
   status changed (a few thousand). Change `orders` to `customer` in the path: the last line holds
   about 150 customers (50 new, 100 changed).

2. The deletes are not captured. The simulated day deleted 30 customers in Postgres; look for them
   in bronze:

   ```sql
   SELECT count(DISTINCT b.custkey) AS deleted_but_in_bronze
   FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cursor/oltp/customer/*.parquet') b
   WHERE NOT EXISTS (FROM source.oltp.customer c WHERE c.custkey = b.custkey);
   ```

   Expected: `30` after one simulated day (30 more per day). They are still in bronze, with nothing
   marking them as deleted. Lab 2.05 captures them.

## Questions

1. Why does sync 2 read thousands of rows instead of millions?
2. A customer changed twice between two syncs: how many rows does bronze get for it?
3. Why can a date cursor never see a delete?
4. What would happen if a script changed a row without changing `updated_at`?

## Cleanup

Stop the tunnels with `Ctrl+C` in their windows. Keep the source, destination and connection: they
live in Airbyte's database, which the turn-off backs up and the next bring-up restores. The
Parquet files stay in the bronze bucket, which is kept between environments. To drop the files:

```bash
aws s3 rm s3://eks-for-data-bronze-283429977024/oltp_cursor/ --recursive
```
