[Labs](README.md) › 3.01

# Lab 3.01 — Bronze to Silver, Day by Day

## Goal

Write a Spark job that moves each simulated day's changes in the 8 TPC-H tables from bronze
(Parquet files written by Airbyte) to silver (Iceberg tables in the Polaris catalog). Each silver
table has a declared schema, and the job casts bronze to it. Each run writes only the rows ingested
since the last run into its own partition, keeps each key's last state of the day, and applies
simple treatments. A rerun replaces its partition, so silver stays the same. You pick the day's
rows in two ways and compare them:

- **Watermark:** the job reads, for each table, the latest ingestion time already in silver.
- **Time interval:** you pass the start and end of the interval to the job.

The same job can be organized in three ways, one lab each ([1](#1-choose-how-to-organize-the-code)).
This page holds what they share: concepts, the silver contract, how to run, the days and the
validation.

## Prerequisites

- Phase 03 done up to [Run, 5. Create the Engines' Principal](../../specs/03-processing-spark-iceberg/HOW_TO_RUN.md#5-create-the-engines-principal):
  a Polaris catalog, the engines' principal, and Secret `polaris-credentials` in `spark` and
  `duckdb`.
- [Lab 02 — Date Cursor Ingestion](../../specs/02-transactional-ingestion/lab02-cursor-ingestion.md)
  done: the connection `Postgres oltp (cursor)` → `S3 bronze oltp_cursor` exists and has synced at
  least once.
- The [Airbyte UI](../../HOW_TO_RUN.md#44-airbyte) and the [DuckDB UI](../../HOW_TO_RUN.md#46-duckdb-ui)
  open, with the catalog attached as `lake`
  ([Run, 7. Read the Table with DuckDB](../../specs/03-processing-spark-iceberg/HOW_TO_RUN.md#7-read-the-table-with-duckdb),
  first block).
- Git Bash in the repository root, with push access to `main`.

## Concepts

- **Silver contract:** each silver table is created with a declared schema
  ([Silver Contract](#silver-contract)) before the first write. The job casts every bronze column
  to its declared type; Spark 4 runs in ANSI mode by default, so a value that cannot be converted
  fails the run instead of reaching silver. Bronze columns not in the contract (Airbyte's
  `_airbyte_raw_id`, `_airbyte_meta`, `_airbyte_generation_id`) are dropped.
- **Steps per table:** read the run's bronze rows → cast to the contract → keep the last state per
  key → trim → row hash → other treatments → overwrite the batch → log. The order matters: dedup
  sorts by `updated_at`, so types are enforced first; the hash is taken from the cleaned values.
- **Row hash (`_row_hash`):** a SHA-256 of the row's business columns, the contract columns in
  their declared order, after cast and trim. It leaves out the control columns (`updated_at`,
  `_airbyte_extracted_at`, `_batch`, `_loaded_at`) and the derived ones, which come from business
  columns. Two rows with the same hash hold the same business values, so it tells a real change
  from a row read again, and lets later labs (`MERGE INTO`, SCD) compare versions with one column.
  The values are joined with a separator that does not occur in the data (`\u001f`), and a null
  becomes `\u0000`, so a null never matches an empty text.
- **Batch:** the rows of one run. Each silver table is partitioned by `_batch`, the start of the
  run's interval, so each run writes its own partition. A key updated on 3 days has 3 rows in
  silver, one per batch. Keeping only the latest version is covered in the next labs
  (`MERGE INTO`, SCD).
- **Overwrite by batch:** each run replaces the partition `_batch = <start>` with its rows, in one
  Iceberg commit, and never touches the other partitions. It is Iceberg's equivalent of Delta's
  `overwrite` with `replaceWhere`. Iceberg replaces whole data files, so the condition must match
  whole partitions; that is why the tables are partitioned by `_batch`.
- **Ingestion time (`_airbyte_extracted_at`):** the time Airbyte read the row. It grows with every
  sync, so "rows ingested after T" is exactly one day's sync when T is the end of the previous one.
  `updated_at` is the time the row changed at the source, not when it was ingested.
- **Why a timestamp and not a date:** the simulated days run minutes apart, so several syncs share
  one real calendar date. A filter or partition on `date(_airbyte_extracted_at)` would mix days.
- **Watermark:** the highest `_airbyte_extracted_at` already in a silver table. The job reads it
  before each run and uses it as the batch start, so it needs no state outside the table. A table's
  first run has no watermark: it reads all of bronze into the batch `1970-01-01 00:00:00`. A rerun
  finds no new rows and writes nothing. A run that fails halfway resumes on the next run, table by
  table.
- **Time interval:** you give the interval `[since, until)`: rows ingested at or after `since` and
  before `until`; `since` is the batch start. This is how an orchestrator passes a data interval
  (Airflow's `data_interval_start` and `data_interval_end`, lab 4.4). A rerun with the same interval
  reads exactly the same rows, whatever was synced later, and replaces the same partition: silver
  stays the same (idempotent). A rerun with another `since` writes a new partition, so the bounds
  must be kept.
- **Dedup, the last state of the day:** silver keeps each key's last state of the day. A cursor
  sync reads each row's current state at the source, so one sync holds at most one version of a
  key, but a day with more than one sync holds one version per sync. The job keeps the version with
  the latest `updated_at`, with ties broken by `_airbyte_extracted_at`. A run that covers several
  days (day 0, a skipped day, an old `since`) keeps the last state of the whole interval.
- **Rows read twice at the cursor boundary:** Airbyte may read again the rows whose `updated_at`
  equals the previous sync's cursor (at-least-once delivery). They come with a new
  `_airbyte_extracted_at`, so they pass the filter and reach silver a second time, in the next
  batch: same key, same `updated_at`. Removing them needs a comparison with silver (`MERGE INTO`,
  next labs); validation check 2 counts them.
- **Treatments:** text trimmed in every table; `_batch` and `_loaded_at` (the run's start time, the
  same in all 8 tables) added; the number pulled out of `name` with a regex (`Customer#000000001` →
  `name_number` = 1, in `customer` and `supplier`); `orderpriority` split (`1-URGENT` →
  `priority_number` = 1, `priority_label` = `URGENT`, in `orders`).
- **Deletes:** the date cursor never sees a deleted row, so customers deleted at the source stay in
  silver. CDC (lab 2.5) fixes this, in lab 3.09.
- **Bronze read:** Airbyte writes each table's files to one folder, with no date sub-folders, so
  every run reads all the table's files and then filters them. The cost grows a little each day;
  at lab scale it does not matter.
- **One run for all tables:** one `SparkApplication` loops over the 8 tables. One driver pod is the
  cheapest; a failure stops the tables after it, and a rerun is safe because each batch is
  overwritten. One run per table, isolated and in parallel, comes with Airflow (lab 4.8).
- **How the job reaches Spark:** Argo CD builds ConfigMap `spark-jobs` from the files listed in
  `pipelines/spark/kustomization.yaml` ([D-048](../decisions/048-spark-job-code-delivery.md)); the
  `SparkApplication` mounts it at `/opt/spark/jobs` and is started with `kubectl apply`
  ([D-057](../decisions/057-spark-job-run-start.md)). A ConfigMap holds flat files, with no
  sub-folders, so the job's files sit side by side.

## Silver Contract

Types follow the TPC-H specification: keys `bigint`, money and quantities `decimal(15,2)`, dates
`date`, small counts `int`, text `string`.

| Table | Key | Columns and types | Derived columns |
|---|---|---|---|
| `region` | `regionkey` | `regionkey bigint, name string, comment string` | — |
| `nation` | `nationkey` | `nationkey bigint, name string, regionkey bigint, comment string` | — |
| `supplier` | `suppkey` | `suppkey bigint, name string, address string, nationkey bigint, phone string, acctbal decimal(15,2), comment string, created_at date` | `name_number int` |
| `customer` | `custkey` | `custkey bigint, name string, address string, nationkey bigint, phone string, acctbal decimal(15,2), mktsegment string, comment string, created_at date` | `name_number int` |
| `part` | `partkey` | `partkey bigint, name string, mfgr string, brand string, type string, size int, container string, retailprice decimal(15,2), comment string` | — |
| `partsupp` | `partkey, suppkey` | `partkey bigint, suppkey bigint, availqty int, supplycost decimal(15,2), comment string` | — |
| `orders` | `orderkey` | `orderkey bigint, custkey bigint, orderstatus string, totalprice decimal(15,2), orderdate date, orderpriority string, clerk string, shippriority int, comment string` | `priority_number int, priority_label string` |
| `lineitem` | `orderkey, linenumber` | `orderkey bigint, partkey bigint, suppkey bigint, linenumber int, quantity decimal(15,2), extendedprice decimal(15,2), discount decimal(15,2), tax decimal(15,2), returnflag string, linestatus string, shipdate date, commitdate date, receiptdate date, shipinstruct string, shipmode string, comment string` | — |

Every table also has `updated_at timestamp`, `_airbyte_extracted_at timestamp`,
`_row_hash string`, `_batch timestamp` and `_loaded_at timestamp`, and is partitioned by `_batch`.
`_row_hash` covers the columns of the "Columns and types" column only.

## Steps

### 1. Choose How to Organize the Code

The three labs build the same job, with the same arguments, log and results. They differ in where
each table's contract and treatments live, and how the common steps are reused:

| Lab | Organization | Files in `pipelines/spark/` |
|---|---|---|
| [3.01 A](lab_transformation_3.01_A.md) | Metadata-driven: a JSON file describes each table; one generic job applies it | `bronze_to_silver_a.py`, `silver_tables_a.json` |
| [3.01 B](lab_transformation_3.01_B.md) | One self-contained script per table, every step written out in each | `bronze_to_silver_b.py`, 8 × `silver_b_<table>.py` |
| [3.01 C](lab_transformation_3.01_C.md) | Hybrid: a per-table spec in code (columns, key, treatment function) and a shared module for the common steps | `bronze_to_silver_c.py`, `silver_tables_c.py`, `silver_common_c.py` |

Do the chosen lab up to its push, then come back to [3](#3-how-to-run-the-job). To compare them,
do each one with its own namespace.

### 2. The `SparkApplication`

Each lab creates `pipelines/spark/bronze-to-silver-<variant>.yaml` from the content below, with
`<variant>` replaced by `a`, `b` or `c`. It is
[`dedup-orders.yaml`](../../pipelines/spark/dedup-orders.yaml) with another name, script and
arguments. The first argument is the bronze folder of lab 02. `<catalog>`, `<namespace>`, `<since>`
and `<until>` stay as placeholders: each run fills them in ([3](#3-how-to-run-the-job)).

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: bronze-to-silver-<variant>
  namespace: spark
spec:
  type: Python
  mode: cluster
  sparkVersion: 4.0.5
  image: ghcr.io/andrerosalopes/spark:4.0.5-iceberg1.12.0
  imagePullPolicy: Always
  mainApplicationFile: local:///opt/spark/jobs/bronze_to_silver_<variant>.py
  arguments:
    - "s3a://eks-for-data-bronze-283429977024/oltp_cursor/oltp"
    - "<catalog>"
    - "<namespace>"
    - "<since>"
    - "<until>"
  restartPolicy:
    type: Never
  sparkConf:
    spark.hadoop.fs.s3a.aws.credentials.provider: software.amazon.awssdk.auth.credentials.WebIdentityTokenFileCredentialsProvider
    spark.hadoop.fs.s3a.endpoint.region: us-east-1
    spark.sql.extensions: org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions
    spark.sql.catalog.lake: org.apache.iceberg.spark.SparkCatalog
    spark.sql.catalog.lake.type: rest
    spark.sql.catalog.lake.uri: http://polaris.polaris.svc.cluster.local:8181/api/catalog
    spark.sql.catalog.lake.scope: PRINCIPAL_ROLE:ALL
    spark.sql.catalog.lake.token-refresh-enabled: "true"
    spark.sql.catalog.lake.client.region: us-east-1
    spark.sql.catalog.lake.header.X-Iceberg-Access-Delegation: vended-credentials
    spark.redaction.regex: (?i)secret|password|token|access[.]?key|credential
  volumes:
    - name: jobs
      configMap:
        name: spark-jobs
  driver:
    annotations:
      karpenter.sh/do-not-disrupt: "true"
    serviceAccount: spark
    volumeMounts:
      - name: jobs
        mountPath: /opt/spark/jobs
    envFrom:
      - secretRef:
          name: polaris-credentials
  executor:
    instances: 2
    annotations:
      karpenter.sh/do-not-disrupt: "true"
    serviceAccount: spark
```

Only the driver mounts the ConfigMap: the job uses the DataFrame API only, so the executors never
run its Python files. A Python UDF would need them on the executors too.

### 3. How to Run the Job

Choose the lab's variant (`a`, `b` or `c`), the catalog (created in phase 03, Run 4) and a new
namespace for this lab:

```bash
VARIANT=<variant>
CATALOG=<catalog>
NAMESPACE=<namespace>
```

Every run below uses these four commands. The `sed` fills in the placeholders without editing the
file. Set `SINCE` and `UNTIL` before each run, as each day says.

```bash
kubectl -n spark delete sparkapplication bronze-to-silver-$VARIANT --ignore-not-found
```

```bash
sed -e "s/<catalog>/$CATALOG/" -e "s/<namespace>/$NAMESPACE/" -e "s/<since>/$SINCE/" -e "s/<until>/$UNTIL/" pipelines/spark/bronze-to-silver-$VARIANT.yaml | kubectl apply -f -
```

```bash
kubectl -n spark get sparkapplication bronze-to-silver-$VARIANT -w
```

Wait for `COMPLETED` (Ctrl+C to stop watching), then read one line per table:

```bash
kubectl -n spark logs bronze-to-silver-$VARIANT-driver | grep "^silver"
```

### 4. Day 0: Initial Load (Watermark)

The tables do not exist yet: the job creates them from the contract, and the watermark mode loads
all of bronze, one row per key, into the batch `1970-01-01 00:00:00`. If lab 02 has already synced
simulated days, only the latest version of each key from all of them is kept.

```bash
SINCE=watermark
UNTIL=none
```

Run the job ([3](#3-how-to-run-the-job)). Expected: 8 lines `since=None until=none written=<n>
replaced=0`, where `<n>` is the number of distinct keys in bronze for each table.

### 5. Day 1 (Watermark)

1. Simulate a day: [phase 02 Run, 3. Simulate a Day](../../specs/02-transactional-ingestion/HOW_TO_RUN.md#3-simulate-a-day).
2. In the Airbyte UI, open the lab02 connection → **Sync now**. Wait for **Succeeded**.
3. Run the job with `SINCE=watermark` and `UNTIL=none`.

Expected: `since=<timestamp of the previous sync>`, `replaced=0`. `customer` writes up to 150 (50
new, 100 updated; the 30 deletes never arrive), `supplier` up to 60, `partsupp` up to 220,
`orders` and `lineitem` the new orders and the status changes, and `region`, `nation` and `part` 0.
Rows at the cursor boundary may be read again by Airbyte, so a few more are possible.

### 6. Rerun Day 1 (Watermark)

Run the job again with `SINCE=watermark` and `UNTIL=none`, with no new sync. Expected:
`written=0 replaced=0` for all 8 tables.

### 7. Day 2 (Time Interval)

The bounds come from the clock of the cluster, where Airbyte also runs, not from your computer's
clock: the DuckDB UI runs its queries in the `duckdb` pod.

1. Simulate a day.
2. **Before** clicking **Sync now**, run in the DuckDB UI:

   ```sql
   SELECT strftime(now() AT TIME ZONE 'UTC', '%Y-%m-%dT%H:%M:%S.%fZ') AS bound;
   ```

   Copy the value into `SINCE`, for example:

   ```bash
   SINCE=2026-11-12T14:00:00.123456Z
   ```

3. **Sync now** and wait for **Succeeded**. Run the same query again and copy the value into
   `UNTIL`.
4. Run the job. Keep `SINCE` and `UNTIL` for [9](#9-rerun-day-2-time-interval).

Expected: `since=<your SINCE> until=<your UNTIL>`, `replaced=0`, with counts like day 1.

### 8. Day 3 (Watermark)

Simulate a day, sync, and run the job with `SINCE=watermark` and `UNTIL=none`. Expected: `since=`
the latest ingestion time from day 2, `replaced=0`, counts like day 1. The watermark mode works
after an interval run, because it reads the bound from silver.

### 9. Rerun Day 2 (Time Interval)

Run the job again with the `SINCE` and `UNTIL` you kept in [7](#7-day-2-time-interval). Expected:
for each table, `written` = `replaced` = the day 2 count. Day 3 was synced since, but the interval
reads exactly the same rows, and the overwrite replaces the day 2 partition instead of adding a
copy.

## Validation

In the DuckDB UI, replace `<namespace>`. Run the checks for `customer`. To repeat them for another
table, change the table name and its key.

1. **One row per key in each batch:**

   ```sql
   SELECT _batch, _loaded_at, count(*) AS rows, count(DISTINCT custkey) AS keys
   FROM lake.<namespace>.customer
   GROUP BY ALL ORDER BY _batch;
   ```

   Expected: 4 lines (days 0 to 3; the reruns added no batch), and `rows` = `keys` on each. The day
   2 line shows the `_loaded_at` of the rerun in [9](#9-rerun-day-2-time-interval).

2. **Versions read twice at the cursor boundary:**

   ```sql
   SELECT count(*) AS repeated_versions
   FROM (SELECT custkey, updated_at
         FROM lake.<namespace>.customer
         GROUP BY ALL HAVING count(*) > 1);
   ```

   Expected: 0 or a few: the rows Airbyte read again at the cursor boundary, each in two batches.
   Their business values did not change, so both copies have the same `_row_hash`:

   ```sql
   SELECT count(*) AS repeated_with_other_hash
   FROM (SELECT custkey, updated_at
         FROM lake.<namespace>.customer
         GROUP BY ALL HAVING count(*) > 1 AND count(DISTINCT _row_hash) > 1);
   ```

   Expected: 0.

3. **The latest version of each key matches the source:**

   ```sql
   WITH latest AS (
     FROM lake.<namespace>.customer
     QUALIFY row_number() OVER (PARTITION BY custkey ORDER BY updated_at DESC) = 1)
   SELECT
     (SELECT count(*) FROM latest l JOIN source.oltp.customer s USING (custkey)
      WHERE l.updated_at <> s.updated_at) AS stale,
     (SELECT count(*) FROM source.oltp.customer s
      WHERE NOT EXISTS (SELECT 1 FROM latest l WHERE l.custkey = s.custkey)) AS missing,
     (SELECT count(*) FROM latest l
      WHERE NOT EXISTS (SELECT 1 FROM source.oltp.customer s WHERE s.custkey = l.custkey)) AS deleted_at_source;
   ```

   Expected: `stale` = 0 and `missing` = 0 (nothing changed at the source since the last sync), and
   `deleted_at_source` > 0: the customers deleted at the source after they reached bronze (up to 30
   per day; a customer created and deleted between two syncs never reaches bronze).

4. **Treatments:**

   ```sql
   SELECT count(*) FILTER (WHERE name_number <> custkey) AS wrong_number,
          count(*) FILTER (WHERE name <> trim(name) OR address <> trim(address)) AS untrimmed
   FROM lake.<namespace>.customer;
   ```

   ```sql
   SELECT orderpriority, priority_number, priority_label, count(*) AS orders
   FROM lake.<namespace>.orders
   GROUP BY ALL ORDER BY 1;
   ```

   Expected: `wrong_number` = 0 and `untrimmed` = 0. Then 5 lines, from `1-URGENT | 1 | URGENT`
   to `5-LOW | 5 | LOW`.

5. **Contract:**

   ```sql
   DESCRIBE lake.<namespace>.customer;
   ```

   Expected: the columns and types of `customer` in the [Silver Contract](#silver-contract), plus
   `updated_at`, `_airbyte_extracted_at`, `_batch` and `_loaded_at` as timestamps, and
   `_row_hash` as text.

## Questions

1. Why does a rerun leave silver unchanged in both modes, and what makes each mode idempotent?
2. What happens if you rerun day 2 with a `SINCE` one second earlier?
3. Why is `_airbyte_extracted_at`, not `updated_at`, the right column to pick the day's rows?
4. Customer `X` was updated on days 1 and 3. How many rows does it have in silver, and how would you
   read only its current version?
5. Why are the customers deleted at the source still in silver, and which lab fixes this?
6. What happens to a run if a bronze `acctbal` holds a value that does not fit `decimal(15,2)`?

## Cleanup

Delete the finished job (it holds no CPU or memory, but blocks a new run with the same name):

```bash
kubectl -n spark delete sparkapplication bronze-to-silver-$VARIANT
```

The silver tables go with the silver bucket and the catalog at
[Turn Off](../../HOW_TO_RUN.md#51-turn-off). To start this lab over before then, use a new
namespace in [3](#3-how-to-run-the-job).
