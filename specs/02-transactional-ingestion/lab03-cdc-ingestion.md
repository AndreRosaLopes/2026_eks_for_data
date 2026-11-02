[How to Run](../../HOW_TO_RUN.md) › 02 — Transactional Ingestion: [Run](HOW_TO_RUN.md) | [Verify](README.md)

# Lab 03 — CDC Ingestion

Create, in the Airbyte UI, a connection that reads the `oltp` schema of the source Postgres by
Change Data Capture (CDC): Airbyte reads every change from the Postgres WAL through the replication
slot `airbyte_slot`, and writes Parquet files to the S3 bronze bucket. Then simulate a day and sync
again: that day's inserts, updates **and deletes** arrive. The configuration is not saved
([D-021](../../docs/decisions/021-airbyte-connection-ui-lab.md)): repeat this lab in every new
environment.

## Prerequisites

- Steps 02.01 to 02.09 done ([phase README](README.md)): Argo CD shows `airbyte`, `postgres` and
  `duckdb` **Synced** and **Healthy**.
- `oltp` loaded: [2. OLTP Baseline](HOW_TO_RUN.md#2-oltp-baseline) run at least once.
- Git Bash in the repository root, with `set -a; source .env; set +a`.
- The [Airbyte UI](../../HOW_TO_RUN.md#44-airbyte) and the [DuckDB UI](../../HOW_TO_RUN.md#46-duckdb-ui)
  open.

## 1. CDC Setup

Run [4. CDC Setup](HOW_TO_RUN.md#4-cdc-setup). It recreates the slot, so the WAL it held until now
is released and CDC starts from this moment. Expected: its summary lists the 8 `oltp` tables and
`airbyte_slot`.

In the DuckDB UI, check the slot:

```sql
SELECT * FROM postgres_query('source', 'SELECT slot_name, plugin, active, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS wal_held FROM pg_replication_slots');
```

Expected: `airbyte_slot`, `pgoutput`, `active` = `false`, `wal_held` of a few kilobytes.

## 2. Source: Postgres, CDC

**Sources** → **New source** → **Postgres**:

| Field | Value |
|---|---|
| Source name | `Postgres oltp (CDC)` |
| Host | `postgres.postgres.svc.cluster.local` |
| Port | `5432` |
| Database Name | `source` |
| Username | `airbyte` |
| Password | `AIRBYTE_PG_PASSWORD` from `.env` ([How to Run, 4. Access](../../HOW_TO_RUN.md#4-access)) |
| SSL Mode | `disable` (the source Postgres has no TLS; the default `require` fails) |
| Schemas | `oltp` only (remove `public`) |
| Update Method | **Read Changes using Change Data Capture (CDC)** |
| Replication Slot | `airbyte_slot` |
| Publication | `airbyte_publication` |
| Advanced fields | Keep the defaults |

**Set up source**. Expected: the connection test passes.

## 3. Destination: S3 Bronze, Parquet

**Destinations** → **New destination** → **S3**:

| Field | Value |
|---|---|
| Destination name | `S3 bronze oltp_cdc` |
| S3 Bucket Name | `eks-for-data-bronze-283429977024` |
| S3 Bucket Path | `oltp_cdc` ([D-042](../../docs/decisions/042-lab-bronze-layout.md)) |
| S3 Bucket Region | `us-east-1` |
| Output Format | **Parquet: Columnar Storage**, Compression Codec `SNAPPY` |
| Access Key ID, Secret Access Key, Role ARN | **Empty**: the connector uses the pod's IAM role (IRSA), as in lab01 |

**Set up destination**. Expected: the connection test passes.

## 4. Connection and Sync 1

**Connections** → **New connection** → source `Postgres oltp (CDC)` → destination
`S3 bronze oltp_cdc`:

| Field | Value |
|---|---|
| Streams | All 8 (`customer`, `lineitem`, `nation`, `orders`, `part`, `partsupp`, `region`, `supplier`), selected |
| Sync mode | **Incremental \| Append** for each stream |
| Cursor field | Set by the source (`_ab_cdc_lsn`, the WAL position); nothing to choose |
| Primary key | As detected from the table |

Then **Next** → **Configure connection**:

| Field | Value |
|---|---|
| Destination Namespace | **Source-defined** (writes to `oltp_cdc/oltp/<table>/`) |
| When the source schema changes | **Propagate field changes only** |
| Be notified when schema changes occur | Off |
| Backfill new or renamed columns | Off |
| Schedule | **Manual** |

**Set up connection**, then **Sync now**. Expected: the sync ends as **Succeeded** (several minutes:
the first sync is a snapshot of every row).

Check it in the DuckDB UI: rows in bronze per table, next to the rows in Postgres:

```sql
SELECT t, bronze, postgres FROM (
  SELECT 'customer' AS t, (SELECT count(*) FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cdc/oltp/customer/*.parquet')) AS bronze, (SELECT count(*) FROM source.oltp.customer) AS postgres
  UNION ALL SELECT 'lineitem', (SELECT count(*) FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cdc/oltp/lineitem/*.parquet')), (SELECT count(*) FROM source.oltp.lineitem)
  UNION ALL SELECT 'nation', (SELECT count(*) FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cdc/oltp/nation/*.parquet')), (SELECT count(*) FROM source.oltp.nation)
  UNION ALL SELECT 'orders', (SELECT count(*) FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cdc/oltp/orders/*.parquet')), (SELECT count(*) FROM source.oltp.orders)
  UNION ALL SELECT 'part', (SELECT count(*) FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cdc/oltp/part/*.parquet')), (SELECT count(*) FROM source.oltp.part)
  UNION ALL SELECT 'partsupp', (SELECT count(*) FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cdc/oltp/partsupp/*.parquet')), (SELECT count(*) FROM source.oltp.partsupp)
  UNION ALL SELECT 'region', (SELECT count(*) FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cdc/oltp/region/*.parquet')), (SELECT count(*) FROM source.oltp.region)
  UNION ALL SELECT 'supplier', (SELECT count(*) FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cdc/oltp/supplier/*.parquet')), (SELECT count(*) FROM source.oltp.supplier)
);
```

Expected: `bronze` = `postgres` for the 8 tables.

## 5. Simulate a Day and Sync 2

1. In the terminal, run [3. Simulate a Day](HOW_TO_RUN.md#3-simulate-a-day) **once**. Expected: its
   summary shows the next `simulated_day`.
2. In the Airbyte UI, open the connection → **Sync now**. Expected: **Succeeded**, with far fewer
   records than sync 1 (thousands, not millions).

## 6. Check Sync 2 in Bronze

Sync 2 holds one record per change Airbyte read from the WAL. In the DuckDB UI, first run this cell
alone; it creates two helpers for this session, `sync1_at` (the time of sync 1 for a table) and
`sync2` (the rows of a table written after sync 1):

```sql
CREATE OR REPLACE TEMP MACRO sync1_at(t) AS
  (SELECT min(_airbyte_extracted_at) FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cdc/oltp/' || t || '/*.parquet'));
CREATE OR REPLACE TEMP MACRO sync2(t) AS TABLE
  SELECT * FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cdc/oltp/' || t || '/*.parquet')
  WHERE _airbyte_extracted_at > (SELECT min(_airbyte_extracted_at) FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cdc/oltp/' || t || '/*.parquet'));
```

Then, in a new cell, compare per table the rows of sync 2 (`sync2_rows`), the rows Postgres changed
after sync 1 (`changed`), and the changed keys that are not in sync 2 (`missing`):

```sql
SELECT 'customer' AS t,
       (SELECT count(*) FROM sync2('customer')) AS sync2_rows,
       (SELECT count(*) FROM source.oltp.customer WHERE updated_at > sync1_at('customer')) AS changed,
       (SELECT count(*) FROM (SELECT custkey FROM source.oltp.customer WHERE updated_at > sync1_at('customer')
                              EXCEPT SELECT custkey FROM sync2('customer'))) AS missing
UNION ALL
SELECT 'lineitem',
       (SELECT count(*) FROM sync2('lineitem')),
       (SELECT count(*) FROM source.oltp.lineitem WHERE updated_at > sync1_at('lineitem')),
       (SELECT count(*) FROM (SELECT orderkey, linenumber FROM source.oltp.lineitem WHERE updated_at > sync1_at('lineitem')
                              EXCEPT SELECT orderkey, linenumber FROM sync2('lineitem')))
UNION ALL
SELECT 'nation',
       (SELECT count(*) FROM sync2('nation')),
       (SELECT count(*) FROM source.oltp.nation WHERE updated_at > sync1_at('nation')),
       (SELECT count(*) FROM (SELECT nationkey FROM source.oltp.nation WHERE updated_at > sync1_at('nation')
                              EXCEPT SELECT nationkey FROM sync2('nation')))
UNION ALL
SELECT 'orders',
       (SELECT count(*) FROM sync2('orders')),
       (SELECT count(*) FROM source.oltp.orders WHERE updated_at > sync1_at('orders')),
       (SELECT count(*) FROM (SELECT orderkey FROM source.oltp.orders WHERE updated_at > sync1_at('orders')
                              EXCEPT SELECT orderkey FROM sync2('orders')))
UNION ALL
SELECT 'part',
       (SELECT count(*) FROM sync2('part')),
       (SELECT count(*) FROM source.oltp.part WHERE updated_at > sync1_at('part')),
       (SELECT count(*) FROM (SELECT partkey FROM source.oltp.part WHERE updated_at > sync1_at('part')
                              EXCEPT SELECT partkey FROM sync2('part')))
UNION ALL
SELECT 'partsupp',
       (SELECT count(*) FROM sync2('partsupp')),
       (SELECT count(*) FROM source.oltp.partsupp WHERE updated_at > sync1_at('partsupp')),
       (SELECT count(*) FROM (SELECT partkey, suppkey FROM source.oltp.partsupp WHERE updated_at > sync1_at('partsupp')
                              EXCEPT SELECT partkey, suppkey FROM sync2('partsupp')))
UNION ALL
SELECT 'region',
       (SELECT count(*) FROM sync2('region')),
       (SELECT count(*) FROM source.oltp.region WHERE updated_at > sync1_at('region')),
       (SELECT count(*) FROM (SELECT regionkey FROM source.oltp.region WHERE updated_at > sync1_at('region')
                              EXCEPT SELECT regionkey FROM sync2('region')))
UNION ALL
SELECT 'supplier',
       (SELECT count(*) FROM sync2('supplier')),
       (SELECT count(*) FROM source.oltp.supplier WHERE updated_at > sync1_at('supplier')),
       (SELECT count(*) FROM (SELECT suppkey FROM source.oltp.supplier WHERE updated_at > sync1_at('supplier')
                              EXCEPT SELECT suppkey FROM sync2('supplier')));
```

Expected: `missing` = 0 for every table, and `sync2_rows` ≥ `changed`: a row changed twice in the
day yields two records, and the deleted rows (`customer`, `partsupp`) are in sync 2 but no longer in
Postgres. `nation`, `part` and `region` never change: 0, 0, 0.

## 7. Deletes Are Captured

The simulated day deleted 30 customers in Postgres. CDC wrote each delete as a record with
`_ab_cdc_deleted_at` filled:

```sql
SELECT count(*) AS deleted_customers
FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cdc/oltp/customer/*.parquet')
WHERE _ab_cdc_deleted_at IS NOT NULL;
```

Expected: `30`. These are the deletes that [lab02](lab02-cursor-ingestion.md#7-deletes-are-not-captured)
missed.

## 8. Clean Up

Stop the port-forwards ([How to Run, 4.2 Port-Forwards](../../HOW_TO_RUN.md#42-port-forwards)). Keep
the source, destination and connection: they disappear with Airbyte's database, and the Parquet
files with the bronze bucket, at [Turn Off](../../HOW_TO_RUN.md#51-turn-off).

Optional, when you stop using CDC and no sync is running: drop the slot, so Postgres stops holding
WAL for it ([02.08 Teardown](08-airbyte-user-and-cdc-preparation/spec.md#teardown)). To use CDC
again, rerun [1. CDC Setup](#1-cdc-setup) and **Sync now**. To drop the files earlier:

```bash
aws s3 rm s3://eks-for-data-bronze-283429977024/oltp_cdc/ --recursive
```
