[Labs](README.md) › 3.01

# Lab 3.01 — Bronze to Silver, Day by Day

## Goal

Write a Spark job that moves each simulated day's changes in the 8 TPC-H tables from bronze
(Parquet files written by Airbyte) to silver (Iceberg tables in the Polaris catalog). Each run
appends only the rows ingested since the last run, keeps one row per key within that day, and
applies simple treatments. You pick the day's rows in two ways and compare them:

- **Watermark:** the job reads, for each table, the latest ingestion time already in silver.
- **Timestamp:** you pass the lower bound to the job.

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

- **Append:** each run adds rows to the silver table and never changes rows already there. A key
  updated on 3 days has 3 rows in silver, one per day. Keeping only the latest version is covered in
  the next labs (`MERGE INTO`, SCD).
- **Ingestion time (`_airbyte_extracted_at`):** the time Airbyte read the row. It grows with every
  sync, so "rows ingested after T" is exactly one day's sync when T is the end of the previous one.
  `updated_at` is the time the row changed at the source, not when it was ingested.
- **Why a timestamp and not a date:** the simulated days run minutes apart, so several syncs share
  one real calendar date. A filter on `date(_airbyte_extracted_at)` would mix days.
- **Watermark:** the highest `_airbyte_extracted_at` already in a silver table. The job reads it
  before each run, so it needs no state outside the table, and a rerun appends nothing
  (idempotent).
- **Timestamp argument:** you give the bound. This is how an orchestrator passes a data interval
  (Airflow's `data_interval_start`, lab 4.4). A rerun with the same bound appends the same rows
  again, unless the job first deletes what it wrote.
- **Dedup within the day:** if a key changed twice before one sync, bronze holds both versions. The
  job keeps the one with the latest `updated_at`, with ties broken by `_airbyte_extracted_at`.
- **Treatments:** text trimmed; Airbyte's columns dropped except `_airbyte_extracted_at`;
  `_loaded_at` (the run time) added; the number pulled out of `name` with a regex
  (`Customer#000000001` → `name_number` = 1, in `customer` and `supplier`); `orderpriority` split
  (`1-URGENT` → `priority_number` = 1, `priority_label` = `URGENT`).
- **Deletes:** the date cursor never sees a deleted row, so customers deleted at the source stay in
  silver. CDC (lab 2.5) fixes this, in lab 3.09.
- **How the job reaches Spark:** Argo CD builds ConfigMap `spark-jobs` from the scripts listed in
  `pipelines/spark/kustomization.yaml` ([D-048](../decisions/048-spark-job-code-delivery.md)); the
  `SparkApplication` mounts it and is started with `kubectl apply`
  ([D-057](../decisions/057-spark-job-run-start.md)).

## Steps

### 1. Write the Job

Create `pipelines/spark/bronze_to_silver.py` and add the five blocks below to it, in order.

**1.1 Arguments, tables and Spark session.** The job takes three arguments: catalog, namespace and
`since` (`watermark` or a UTC timestamp such as `2026-11-12T14:00:00Z`). `KEYS` lists each table
with its primary key. The session connects to Polaris with the engines' principal, as
[`dedup_orders.py`](../../pipelines/spark/dedup_orders.py) does.

```python
"""Appends each day's bronze rows of the 8 oltp tables to silver Iceberg tables (lab 3.01)."""
import os
import sys

from pyspark.sql import SparkSession, Window, functions as F

BRONZE = "s3a://eks-for-data-bronze-283429977024/oltp_cursor/oltp/{}/"
KEYS = {
    "region": ["regionkey"],
    "nation": ["nationkey"],
    "supplier": ["suppkey"],
    "customer": ["custkey"],
    "part": ["partkey"],
    "partsupp": ["partkey", "suppkey"],
    "orders": ["orderkey"],
    "lineitem": ["orderkey", "linenumber"],
}
catalog, namespace, since = sys.argv[1:4]

spark = (
    SparkSession.builder.appName("bronze-to-silver")
    .config("spark.sql.catalog.lake.warehouse", catalog)
    .config("spark.sql.catalog.lake.credential",
            f"{os.environ['POLARIS_CLIENT_ID']}:{os.environ['POLARIS_CLIENT_SECRET']}")
    .getOrCreate()
)
spark.sql(f"CREATE NAMESPACE IF NOT EXISTS lake.{namespace}")
```

**1.2 The day's rows.** For each table, the lower bound is either the watermark (the latest
`_airbyte_extracted_at` in silver; none on the first run, so everything is read) or the timestamp
you passed. Only bronze rows ingested after it are kept.

```python
for table, key in KEYS.items():
    target = f"lake.{namespace}.{table}"
    exists = spark.sql(f"SHOW TABLES IN lake.{namespace} LIKE '{table}'").count() > 0

    if since == "watermark":
        bound = (spark.table(target).agg(F.max("_airbyte_extracted_at")).first()[0]
                 if exists else None)
    else:
        bound = since
    day = spark.read.parquet(BRONZE.format(table))
    if bound is not None:
        day = day.where(F.col("_airbyte_extracted_at") > F.lit(bound).cast("timestamp"))
```

**1.3 Dedup within the day.** A window per key, newest `updated_at` first; only rank 1 stays.

```python
    latest = Window.partitionBy(*key).orderBy(
        F.col("updated_at").desc(), F.col("_airbyte_extracted_at").desc())
    day = day.withColumn("_rank", F.row_number().over(latest)).where("_rank = 1").drop("_rank")
```

**1.4 Treatments.** Drop Airbyte's columns except the ingestion time, trim every text column,
extract numbers with `regexp_extract`, and record the load time.

```python
    day = day.drop(*[c for c in day.columns
                     if c.startswith("_airbyte") and c != "_airbyte_extracted_at"])
    for column, dtype in day.dtypes:
        if dtype == "string":
            day = day.withColumn(column, F.trim(column))
    if table in ("customer", "supplier"):
        day = day.withColumn(
            "name_number", F.regexp_extract("name", r"#(\d+)$", 1).cast("int"))
    if table == "orders":
        day = (day
               .withColumn("priority_number",
                           F.regexp_extract("orderpriority", r"^(\d)-", 1).cast("int"))
               .withColumn("priority_label",
                           F.regexp_extract("orderpriority", r"^\d-(.+)$", 1)))
    day = day.withColumn("_loaded_at", F.current_timestamp())
```

**1.5 Append.** The first run creates the table; later runs append to it. One log line per table.

```python
    rows = day.count()
    if exists:
        day.writeTo(target).append()
    else:
        day.writeTo(target).create()
    print(f"silver {namespace}.{table}: since={bound} appended={rows}")

spark.stop()
```

### 2. Add the Job to ConfigMap `spark-jobs`

In `pipelines/spark/kustomization.yaml`, add the script under `files`:

```yaml
    files:
      - read_bronze_orders.py
      - dedup_orders.py
      - bronze_to_silver.py
```

### 3. Write the `SparkApplication`

Create `pipelines/spark/bronze-to-silver.yaml` with the content below. It is
[`dedup-orders.yaml`](../../pipelines/spark/dedup-orders.yaml) with another name, script and
arguments. `<catalog>`, `<namespace>` and `<since>` stay as placeholders: each run fills them in
([5](#5-how-to-run-the-job)).

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: bronze-to-silver
  namespace: spark
spec:
  type: Python
  mode: cluster
  sparkVersion: 4.0.5
  image: ghcr.io/andrerosalopes/spark:4.0.5-iceberg1.12.0
  imagePullPolicy: Always
  mainApplicationFile: local:///opt/spark/jobs/bronze_to_silver.py
  arguments:
    - "<catalog>"
    - "<namespace>"
    - "<since>"
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

### 4. Push and Check the ConfigMap

```bash
git add pipelines/spark/bronze_to_silver.py
git add pipelines/spark/kustomization.yaml
git add pipelines/spark/bronze-to-silver.yaml
git commit -m "Add the bronze-to-silver job of lab 3.01"
git push
```

Argo CD syncs Application `spark-jobs` within about 3 minutes (or click **Refresh** in its UI).
Check that the script reached the ConfigMap:

```bash
kubectl -n spark get configmap spark-jobs -o jsonpath='{.data}' | grep -c bronze_to_silver
```

Expected: `1`. After any later change to the script, push again and repeat this check.

### 5. How to Run the Job

Choose the catalog (created in phase 03, Run 4) and a new namespace for this lab:

```bash
CATALOG=<catalog>
NAMESPACE=<namespace>
```

Every run below uses these four commands. The `sed` fills in the placeholders without editing the
file. Set `SINCE` before each run, as each day says.

```bash
kubectl -n spark delete sparkapplication bronze-to-silver --ignore-not-found
```

```bash
sed -e "s/<catalog>/$CATALOG/" -e "s/<namespace>/$NAMESPACE/" -e "s/<since>/$SINCE/" pipelines/spark/bronze-to-silver.yaml | kubectl apply -f -
```

```bash
kubectl -n spark get sparkapplication bronze-to-silver -w
```

Wait for `COMPLETED` (Ctrl+C to stop watching), then read one line per table:

```bash
kubectl -n spark logs bronze-to-silver-driver | grep "^silver"
```

### 6. Day 0: Initial Load (Watermark)

The tables do not exist yet, so the watermark mode loads all of bronze, one row per key.

```bash
SINCE=watermark
```

Run the job ([5](#5-how-to-run-the-job)). Expected: 8 lines `since=None appended=<n>`, where
`<n>` is the number of distinct keys in bronze for each table.

### 7. Day 1 (Watermark)

1. Simulate a day: [phase 02 Run, 3. Simulate a Day](../../specs/02-transactional-ingestion/HOW_TO_RUN.md#3-simulate-a-day).
2. In the Airbyte UI, open the lab02 connection → **Sync now**. Wait for **Succeeded**.
3. Run the job with `SINCE=watermark`.

Expected: `since=<timestamp of the previous sync>`. `customer` appends up to 150 (50 new, 100
updated; the 30 deletes never arrive), `supplier` up to 60, `partsupp` up to 220, `orders` and
`lineitem` the new orders and the status changes, and `region`, `nation` and `part` 0. Rows at the
cursor boundary may be read again by Airbyte (at-least-once), so a few more are possible.

### 8. Rerun Day 1 (Watermark)

Run the job again with `SINCE=watermark`, with no new sync. Expected: `appended=0` for all 8 tables.

### 9. Day 2 (Timestamp)

1. Simulate a day.
2. **Before** clicking **Sync now**, record the bound in UTC:

   ```bash
   SINCE=$(date -u +%Y-%m-%dT%H:%M:%SZ); echo $SINCE
   ```

3. **Sync now**, wait for **Succeeded**, then run the job.

Expected: `since=<your SINCE>`, with counts like day 1. The bound comes from your computer's clock:
if it runs ahead of AWS by more than the time between this command and the sync, rows are missed.

### 10. Day 3 (Watermark)

Simulate a day, sync, and run the job with `SINCE=watermark`. Expected: `since=` the latest
ingestion time from day 2, counts like day 1. The watermark mode works after a timestamp run,
because it reads the bound from silver.

## Validation

In the DuckDB UI, replace `<namespace>`. Run the checks for `customer`. To repeat them for another
table, change the table name and its key.

1. **One row per key in each run:**

   ```sql
   SELECT _loaded_at, count(*) AS rows, count(DISTINCT custkey) AS keys
   FROM lake.<namespace>.customer
   GROUP BY _loaded_at ORDER BY _loaded_at;
   ```

   Expected: 4 lines (days 0 to 3; the rerun added nothing), and `rows` = `keys` on each.

2. **The latest version of each key matches the source:**

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
   `deleted_at_source` a multiple of 30: the customers deleted after they reached bronze.

3. **Treatments:**

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

## Break It

Run the job again with the day 2 bound (the `SINCE` you recorded in [9](#9-day-2-timestamp)).
Expected: the log shows `appended` > 0 for the tables that changed on days 2 and 3. Diagnose it with
check 1: a fifth `_loaded_at` line. Then find the rows loaded twice:

```sql
SELECT custkey, _airbyte_extracted_at, count(*) AS copies
FROM lake.<namespace>.customer
GROUP BY ALL HAVING count(*) > 1
LIMIT 10;
```

Expected: rows with `copies` = 2: the same bronze row, appended by two runs. The timestamp mode is
not idempotent by itself.

## Questions

1. Why does the watermark mode append nothing on a rerun, while the timestamp mode appends again?
2. What would the job have to do before appending, so that a rerun with the same timestamp leaves
   silver unchanged?
3. Why is `_airbyte_extracted_at`, not `updated_at`, the right column to pick the day's rows?
4. Customer `X` was updated on days 1 and 3. How many rows does it have in silver, and how would you
   read only its current version?
5. Why are the customers deleted at the source still in silver, and which lab fixes this?

## Cleanup

Delete the finished job (it holds no CPU or memory, but blocks a new run with the same name):

```bash
kubectl -n spark delete sparkapplication bronze-to-silver
```

The silver tables go with the silver bucket and the catalog at
[Turn Off](../../HOW_TO_RUN.md#51-turn-off). To start this lab over before then, use a new
namespace in [5](#5-how-to-run-the-job).
