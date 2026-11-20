[Labs](README.md) › 2.05

# Lab 2.05 — CDC Ingestion with Airbyte

## Goal

Create, in the Airbyte UI, a connection that reads the `oltp` schema of the source Postgres by
Change Data Capture (CDC) through the replication slot `airbyte_slot`, and writes Parquet files to
the S3 bronze bucket. Then simulate a day and sync again: that day's inserts, updates **and
deletes** arrive.

## Prerequisites

1. [Lab 2.03 — CDC Setup on Postgres](lab_ingestion_2.03.md) done: the publication
   `airbyte_publication` and the slot `airbyte_slot` exist.
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

If **Sources** already lists `Postgres oltp (CDC)`, the environment was restored from a backup with
this lab's objects: skip steps 1 to 5 and go to [step 6](#6-simulate-a-day-and-sync-2). Recreating
the slot would discard the position the connection has already read.

## Concepts

- **CDC (Change Data Capture):** Airbyte reads every insert, update and delete from the Postgres
  WAL (Write-Ahead Log, the log of every change) through the slot, instead of querying the tables.
  The publication, the slot and the WAL limit are explained in lab 2.03.
- **Snapshot, then changes:** the first sync copies every row (a snapshot) and records the slot's
  position. Each later sync reads only the changes after that position, and the slot then releases
  the WAL already read.
- **Incremental | Append:** each change is appended to bronze as a new row. A row changed twice
  appears twice.
- **CDC metadata columns:** Airbyte adds `_ab_cdc_lsn` (the change's position in the WAL, used as
  the cursor), `_ab_cdc_updated_at` (when the change happened) and `_ab_cdc_deleted_at` (filled
  only for deletes). `_airbyte_extracted_at` is the time the sync read the row.
- **Deletes:** a delete reaches bronze as a row with the primary key and `_ab_cdc_deleted_at`
  filled. This is what the date cursor of lab 2.04 cannot see.
- **Layout:** this lab writes to `oltp_cdc`, next to `oltp_cursor` of lab 2.04, with the same table
  names, so the two methods can be compared ([D-042](../decisions/042-lab-bronze-layout.md)).

## Steps

### 1. Start CDC from Now

Recreate the publication and the slot, so CDC starts from this moment and the WAL the slot held
since lab 2.03 is released (a few seconds):

```bash
MSYS_NO_PATHCONV=1 kubectl -n duckdb exec -i deploy/duckdb -- /duckdb < pipelines/tpch/04-cdc-setup.sql
```

Expected: the summary lists `airbyte_slot` (`pgoutput, logical`) and the 8 `oltp` tables in
`airbyte_publication`.

In the DuckDB UI, check the slot:

```sql
SELECT * FROM postgres_query('source', 'SELECT slot_name, plugin, active, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS wal_held FROM pg_replication_slots');
```

Expected: `airbyte_slot`, `pgoutput`, `active` = `false`, `wal_held` of a few kilobytes.

### 2. Source: Postgres, CDC

**Sources** → **New source** → **Postgres**:

| Field | Value |
|---|---|
| Source name | `Postgres oltp (CDC)` |
| Host | `postgres.postgres.svc.cluster.local` |
| Port | `5432` |
| Database Name | `source` |
| Username | `airbyte` |
| Password | The password printed in prerequisite 5 |
| SSL Mode | `disable` (the source Postgres has no TLS; the default `require` fails) |
| Schemas | `oltp` only (remove `public`) |
| Update Method | **Read Changes using Change Data Capture (CDC)** |
| Replication Slot | `airbyte_slot` |
| Publication | `airbyte_publication` |
| Advanced fields | Keep the defaults |

**Set up source**. Expected: the connection test passes.

### 3. Destination: S3 Bronze, Parquet

**Destinations** → **New destination** → **S3**:

| Field | Value |
|---|---|
| Destination name | `S3 bronze oltp_cdc` |
| S3 Bucket Name | `eks-for-data-bronze-283429977024` |
| S3 Bucket Path | `oltp_cdc` |
| S3 Bucket Region | `us-east-1` |
| Output Format | **Parquet: Columnar Storage**, Compression Codec `SNAPPY` |
| Access Key ID, Secret Access Key, Role ARN | **Empty**: the connector uses the pod's IAM role |

**Set up destination**. Expected: the connection test passes.

### 4. Connection

**Connections** → **New connection** → source `Postgres oltp (CDC)` → destination
`S3 bronze oltp_cdc`:

| Field | Value |
|---|---|
| Streams | All 8 (`customer`, `lineitem`, `nation`, `orders`, `part`, `partsupp`, `region`, `supplier`), selected |
| Sync mode | **Incremental \| Append** for each stream |
| Cursor field | Set by the source (`_ab_cdc_lsn`); nothing to choose |
| Primary key | As detected from the table |

Then **Next** → **Configure connection**:

| Field | Value |
|---|---|
| Destination Namespace | **Source-defined** (writes to `oltp_cdc/oltp/<table>/`) |
| When the source schema changes | **Propagate field changes only** |
| Be notified when schema changes occur | Off |
| Backfill new or renamed columns | Off |
| Schedule | **Manual** |

**Set up connection**.

### 5. Sync 1

**Sync now**. Expected: the sync ends as **Succeeded** after several minutes: the first sync is a
snapshot of every row.

In the DuckDB UI, compare the rows in bronze with the rows in Postgres:

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

### 6. Simulate a Day and Sync 2

1. From the repository root, **once** (about 1 minute):

   ```bash
   MSYS_NO_PATHCONV=1 kubectl -n duckdb exec -i deploy/duckdb -- /duckdb < pipelines/tpch/03-simulate-day.sql
   ```

   Expected: the summary shows the next `simulated_day`.

2. In the Airbyte UI, open the connection → **Sync now**. Expected: **Succeeded**, with far fewer
   records than sync 1 (thousands, not millions).

## Validation

In the DuckDB UI.

1. Sync 2 holds one row per change Airbyte read from the WAL. First run this cell alone; it creates
   two helpers for this session, `sync1_at` (the time of sync 1 for a table) and `sync2` (the rows of
   a table written after sync 1):

   ```sql
   CREATE OR REPLACE TEMP MACRO sync1_at(t) AS
     (SELECT min(_airbyte_extracted_at) FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cdc/oltp/' || t || '/*.parquet'));
   CREATE OR REPLACE TEMP MACRO sync2(t) AS TABLE
     SELECT * FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cdc/oltp/' || t || '/*.parquet')
     WHERE _airbyte_extracted_at > (SELECT min(_airbyte_extracted_at) FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cdc/oltp/' || t || '/*.parquet'));
   ```

   Then, in a new cell, compare per table the rows of sync 2 (`sync2_rows`), the rows Postgres
   changed after sync 1 (`changed`), and the changed keys that are not in sync 2 (`missing`):

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
   day yields two rows, and the deleted rows (`customer`, `partsupp`) are in sync 2 but no longer in
   Postgres. `nation`, `part` and `region` never change: 0, 0, 0.

2. The deletes are captured. The simulated day deleted 30 customers in Postgres; CDC wrote each
   delete as a row with `_ab_cdc_deleted_at` filled:

   ```sql
   SELECT count(*) AS deleted_customers
   FROM read_parquet('s3://eks-for-data-bronze-283429977024/oltp_cdc/oltp/customer/*.parquet')
   WHERE _ab_cdc_deleted_at IS NOT NULL;
   ```

   Expected: `30` after one simulated day (30 more per day). These are the deletes that lab 2.04
   missed.

## Questions

1. Why does the first CDC sync read every row, while the later ones read only changes?
2. Compare `_ab_cdc_updated_at` with `_airbyte_extracted_at` for a changed customer: what does
   each one record?
3. Why is `sync2_rows` larger than `changed` for `customer`?
4. What happens to the slot, and to the Postgres disk, if you simulate many days without syncing?

## Cleanup

Stop the tunnels with `Ctrl+C` in their windows. Keep the source, destination and connection: they
live in Airbyte's database, which the turn-off backs up and the next bring-up restores. The
Parquet files stay in the bronze bucket, which is kept between environments.

When you stop using CDC, and no sync is running, drop the slot so Postgres stops keeping WAL for
it. In the DuckDB UI:

```sql
CALL postgres_execute('source', $$
SELECT pg_drop_replication_slot('airbyte_slot')
$$);
```

To use CDC again, run [step 1](#1-start-cdc-from-now), then **Sync now**. To drop the files:

```bash
aws s3 rm s3://eks-for-data-bronze-283429977024/oltp_cdc/ --recursive
```
