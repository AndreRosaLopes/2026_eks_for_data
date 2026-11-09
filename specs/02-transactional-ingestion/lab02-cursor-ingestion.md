[How to Run](../../HOW_TO_RUN.md) › 02 — Transactional Ingestion: [Run](HOW_TO_RUN.md) | [Verify](README.md)

# Lab 02 — Date Cursor Ingestion

Create, in the Airbyte UI, a connection that reads the `oltp` schema of the source Postgres
incrementally by the `updated_at` column and writes Parquet files to the S3 bronze bucket. Then
simulate a day and sync again: only that day's inserts and updates arrive, **and deletes do not**.
The configuration is not saved ([D-021](../../docs/decisions/021-airbyte-connection-ui-lab.md)):
repeat this lab in every new environment.

## Prerequisites

- Steps 02.01 to 02.08 done ([phase README](README.md)): Argo CD shows `airbyte`, `postgres` and
  `duckdb` **Synced** and **Healthy**.
- `oltp` loaded: [2. OLTP Baseline](HOW_TO_RUN.md#2-oltp-baseline) run at least once.
- Git Bash in the repository root, with `set -a; source .env; set +a`.

## 1. Open the Airbyte UI

Follow [How to Run, 4.4 Airbyte](../../HOW_TO_RUN.md#44-airbyte).

## 2. Source: Postgres, User-Defined Cursor

**Sources** → **New source** → **Postgres**:

| Field | Value |
|---|---|
| Source name | `Postgres oltp (cursor)` |
| Host | `postgres.postgres.svc.cluster.local` |
| Port | `5432` |
| Database Name | `source` |
| Username | `airbyte` |
| Password | `AIRBYTE_PG_PASSWORD` from `.env` ([How to Run, 4. Access](../../HOW_TO_RUN.md#4-access)) |
| SSL Mode | `disable` (the source Postgres has no TLS) |
| Schemas | `oltp` only (remove `public`) |
| Update Method | **Scan Changes with User Defined Cursor** |

**Set up source**. Expected: the connection test passes.

## 3. Destination: S3 Bronze, Parquet

**Destinations** → **New destination** → **S3**:

| Field | Value |
|---|---|
| Destination name | `S3 bronze oltp_cursor` |
| S3 Bucket Name | `eks-for-data-bronze-283429977024` |
| S3 Bucket Path | `oltp_cursor` ([D-042](../../docs/decisions/042-lab-bronze-layout.md)) |
| S3 Bucket Region | `us-east-1` |
| Output Format | **Parquet: Columnar Storage**, Compression Codec `SNAPPY` |
| Access Key ID, Secret Access Key, Role ARN | **Empty**: the connector uses the pod's IAM role (IRSA), as in lab01 |

**Set up destination**. Expected: the connection test passes.

## 4. Connection and Sync 1

**Connections** → **New connection** → source `Postgres oltp (cursor)` → destination
`S3 bronze oltp_cursor`:

| Field | Value |
|---|---|
| Streams | All 8 (`customer`, `lineitem`, `nation`, `orders`, `part`, `partsupp`, `region`, `supplier`), selected |
| Select Sync Mode | **Append Historical Changes** |
| Append mode | **Append new rows and updates only** (Incremental \| Append) for each stream |
| Cursor | `updated_at` for each stream ([D-028](../../docs/decisions/028-lab02-cursor.md)) |
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

**Set up connection**, then **Sync now**. Expected: the sync ends as **Succeeded** (several minutes:
it reads about 1.37 million orders and 6 million line items).

Check it in the [DuckDB UI](../../HOW_TO_RUN.md#46-duckdb-ui): rows in bronze per table, next to
the rows in Postgres:

```sql
SELECT 'orders' AS t,
       (FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cursor/oltp/orders/*.parquet') SELECT count(*)) AS bronze,
       (FROM source.oltp.orders SELECT count(*)) AS postgres
UNION ALL
SELECT 'customer',
       (FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cursor/oltp/customer/*.parquet') SELECT count(*)),
       (FROM source.oltp.customer SELECT count(*));
```

Expected: `bronze` = `postgres` for both.

## 5. Simulate a Day and Sync 2

1. In the terminal, run [3. Simulate a Day](HOW_TO_RUN.md#3-simulate-a-day). Expected: its summary
   shows the next `simulated_day`.
2. In the Airbyte UI, open the connection → **Sync now**. Expected: **Succeeded**, with far fewer
   records than sync 1 (thousands, not millions).

## 6. Check Sync 2 in Bronze

Each sync writes new files. In the DuckDB UI, count the rows per file timestamp (one line per sync):

```sql
SELECT regexp_extract(filename, '_(\d{10,13})_', 1) AS sync_epoch, count(*) AS rows
FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cursor/oltp/orders/*.parquet', filename = true)
GROUP BY ALL ORDER BY sync_epoch;
```

Expected: two lines; the second one holds the day's new orders plus the orders whose status
changed (a few thousand). Change `orders` to `customer` in the path: the second line holds about
150 customers (50 new, 100 changed).

## 7. Deletes Are Not Captured

The simulated day deleted 30 customers in Postgres. Look for them in bronze:

```sql
SELECT count(DISTINCT b.custkey) AS deleted_but_in_bronze
FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cursor/oltp/customer/*.parquet') b
WHERE NOT EXISTS (FROM source.oltp.customer c WHERE c.custkey = b.custkey);
```

Expected: `30`. They are still in bronze, with nothing marking them as deleted: a cursor only sees
rows that exist. [Lab 03 — CDC](lab03-cdc-ingestion.md) captures them.

## 8. Clean Up

Stop the port-forwards ([How to Run, 4.2 Port-Forwards](../../HOW_TO_RUN.md#42-port-forwards)).
Nothing else: the source, destination and connection disappear with Airbyte's database, and the
Parquet files with the bronze bucket, at [Turn Off](../../HOW_TO_RUN.md#51-turn-off). To drop the
files earlier:

```bash
aws s3 rm s3://eks-for-data-bronze-283429977024/oltp_cursor/ --recursive
```
