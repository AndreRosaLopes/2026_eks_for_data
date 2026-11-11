[Labs](README.md) › [3.01](lab_transformation_3.01.md) › B

# Lab 3.01 B — One Script per Table

## Goal

Build the [lab 3.01](lab_transformation_3.01.md) job as one self-contained script per table: each
script writes out every step for its own table, column by column, and shares no code with the
others. A small entry point runs the 8 scripts in one `SparkApplication`.

## Prerequisites

[Lab 3.01](lab_transformation_3.01.md) read up to [1](lab_transformation_3.01.md#1-choose-how-to-organize-the-code),
with its prerequisites done.

## Concepts

- **Nine files, two roles:**

  | File | Role |
  |---|---|
  | `silver_b_<table>.py` (8 files) | Everything for one table: `CREATE TABLE`, read, cast and trim per column, dedup, treatments, write, log |
  | `bronze_to_silver_b.py` | Entry point: arguments, Spark session, calls the 8 scripts in order |

- **Explicit:** each script reads top to bottom with no indirection; every column, type and
  treatment of the table is in one place.
- **Duplicated:** the read, watermark, dedup, write and log are copied 8 times. A fix to one of
  them must be repeated in the 8 files, and nothing checks that the copies stay the same.
- **Implications:** adding a table is one new script plus one line in the entry point; a fix to a
  common step is 8 edits; the scripts are easy to read alone, and the whole is harder to keep
  consistent.

## Steps

### 1. Write the `customer` Script

Create `pipelines/spark/silver_b_customer.py`. It runs the steps of
[lab 3.01, Concepts, Steps per table](lab_transformation_3.01.md#concepts) for `customer` only.

```python
"""Silver customer (lab 3.01 B): every step written out for this table."""
from datetime import datetime, timezone

from pyspark.sql import Window, functions as F

FIRST_BATCH = datetime(1970, 1, 1, tzinfo=timezone.utc)


def utc(text):
    """Parses a UTC timestamp such as 2026-11-12T14:00:00.000000Z."""
    return datetime.fromisoformat(text.replace("Z", "+00:00"))


def run(spark, bronze, namespace, since, until, loaded_at):
    target = f"lake.{namespace}.customer"
    extracted = F.col("_airbyte_extracted_at")

    # Contract
    spark.sql(f"""
        CREATE TABLE IF NOT EXISTS {target} (
          custkey bigint, name string, address string, nationkey bigint, phone string,
          acctbal decimal(15,2), mktsegment string, comment string, created_at date,
          name_number int,
          updated_at timestamp, _airbyte_extracted_at timestamp,
          _batch timestamp, _loaded_at timestamp)
        USING iceberg PARTITIONED BY (_batch)""")

    # The run's rows and batch
    day = spark.read.parquet(f"{bronze}/customer/")
    if since == "watermark":
        bound = spark.table(target).agg(F.max(extracted)).first()[0]
        if bound is not None:
            day = day.where(extracted > F.lit(bound))
        batch = bound or FIRST_BATCH
    else:
        bound, batch = since, utc(since)
        day = day.where(extracted >= F.lit(batch))
    if until != "none":
        day = day.where(extracted < F.lit(utc(until)))

    # Cast and trim, column by column
    day = day.select(
        F.col("custkey").cast("bigint").alias("custkey"),
        F.trim(F.col("name").cast("string")).alias("name"),
        F.trim(F.col("address").cast("string")).alias("address"),
        F.col("nationkey").cast("bigint").alias("nationkey"),
        F.trim(F.col("phone").cast("string")).alias("phone"),
        F.col("acctbal").cast("decimal(15,2)").alias("acctbal"),
        F.trim(F.col("mktsegment").cast("string")).alias("mktsegment"),
        F.trim(F.col("comment").cast("string")).alias("comment"),
        F.col("created_at").cast("date").alias("created_at"),
        F.col("updated_at").cast("timestamp").alias("updated_at"),
        extracted.cast("timestamp").alias("_airbyte_extracted_at"),
    )

    # Last state per key
    latest = Window.partitionBy("custkey").orderBy(
        F.col("updated_at").desc(), extracted.desc())
    day = day.withColumn("_rank", F.row_number().over(latest)).where("_rank = 1").drop("_rank")

    # Treatments
    day = (day
           .withColumn("name_number", F.regexp_extract("name", r"#(\d+)$", 1).cast("int"))
           .withColumn("_batch", F.lit(batch))
           .withColumn("_loaded_at", F.lit(loaded_at)))

    # Overwrite the batch and log
    day.select(spark.table(target).columns).writeTo(target).overwrite(
        F.col("_batch") == F.lit(batch))
    written, replaced = spark.sql(
        "SELECT coalesce(summary['added-records'], '0'), coalesce(summary['deleted-records'], '0') "
        f"FROM {target}.snapshots ORDER BY committed_at DESC LIMIT 1").first()
    print(f"silver {namespace}.customer: since={bound} until={until} "
          f"written={written} replaced={replaced}")
```

The rows written (`added-records`) and replaced (`deleted-records`) come from the summary of the
snapshot the overwrite just committed, so Spark does not count the data. A key is missing from the
summary when its count is 0, hence the `coalesce`.

### 2. Write the Other 7 Scripts

For each other table, copy `silver_b_customer.py` to `pipelines/spark/silver_b_<table>.py` and
change, from the table's line in the [Silver Contract](lab_transformation_3.01.md#silver-contract):

| What | Change |
|---|---|
| Docstring, `target`, bronze folder, log line | `customer` → the table name |
| `CREATE TABLE` | The table's columns and derived columns, then the same 4 technical columns |
| `select` | One line per column: `cast` to its type, wrapped in `F.trim` for `string` columns; keep the `updated_at` and `_airbyte_extracted_at` lines |
| `Window.partitionBy` | The table's key (`"partkey", "suppkey"` for `partsupp`; `"orderkey", "linenumber"` for `lineitem`) |
| Treatments | `supplier`: keep the `name_number` line. `orders`: replace it with the two lines below. Other tables: remove it |

```python
           .withColumn("priority_number",
                       F.regexp_extract("orderpriority", r"^(\d)-", 1).cast("int"))
           .withColumn("priority_label",
                       F.regexp_extract("orderpriority", r"^\d-(.+)$", 1))
```

### 3. Write the Entry Point

Create `pipelines/spark/bronze_to_silver_b.py`. The driver runs it from `/opt/spark/jobs`, and
Python adds the script's folder to its import path, so the 8 scripts are found there.

```python
"""Writes each day's bronze rows of the 8 oltp tables to silver Iceberg tables (lab 3.01 B)."""
import os
import sys
from datetime import datetime, timezone

from pyspark.sql import SparkSession

import silver_b_customer
import silver_b_lineitem
import silver_b_nation
import silver_b_orders
import silver_b_part
import silver_b_partsupp
import silver_b_region
import silver_b_supplier

bronze, catalog, namespace, since, until = sys.argv[1:6]
loaded_at = datetime.now(timezone.utc)

spark = (
    SparkSession.builder.appName("bronze-to-silver-b")
    .config("spark.sql.catalog.lake.warehouse", catalog)
    .config("spark.sql.catalog.lake.credential",
            f"{os.environ['POLARIS_CLIENT_ID']}:{os.environ['POLARIS_CLIENT_SECRET']}")
    .getOrCreate()
)
spark.sql(f"CREATE NAMESPACE IF NOT EXISTS lake.{namespace}")

for job in (silver_b_region, silver_b_nation, silver_b_supplier, silver_b_customer,
            silver_b_part, silver_b_partsupp, silver_b_orders, silver_b_lineitem):
    job.run(spark, bronze, namespace, since, until, loaded_at)

spark.stop()
```

### 4. Add the Files to ConfigMap `spark-jobs`

In `pipelines/spark/kustomization.yaml`, add the 9 files under `files`:

```yaml
      - bronze_to_silver_b.py
      - silver_b_region.py
      - silver_b_nation.py
      - silver_b_supplier.py
      - silver_b_customer.py
      - silver_b_part.py
      - silver_b_partsupp.py
      - silver_b_orders.py
      - silver_b_lineitem.py
```

### 5. Write the `SparkApplication`

Create `pipelines/spark/bronze-to-silver-b.yaml` with the content of
[lab 3.01, 2](lab_transformation_3.01.md#2-the-sparkapplication), with `<variant>` replaced by `b`
(two places: `name` and `mainApplicationFile`).

### 6. Push and Check the ConfigMap

```bash
git add pipelines/spark/bronze_to_silver_b.py
git add pipelines/spark/silver_b_region.py
git add pipelines/spark/silver_b_nation.py
git add pipelines/spark/silver_b_supplier.py
git add pipelines/spark/silver_b_customer.py
git add pipelines/spark/silver_b_part.py
git add pipelines/spark/silver_b_partsupp.py
git add pipelines/spark/silver_b_orders.py
git add pipelines/spark/silver_b_lineitem.py
git add pipelines/spark/kustomization.yaml
git add pipelines/spark/bronze-to-silver-b.yaml
git commit -m "Add the bronze-to-silver job of lab 3.01 B"
git push
```

Argo CD syncs Application `spark-jobs` within about 3 minutes (or click **Refresh** in its UI).
Check that the 9 files reached the ConfigMap:

```bash
kubectl -n spark get configmap spark-jobs -o jsonpath='{.data}' | grep -o '"[a-z_]*_b\(_[a-z]*\)\?\.py"' | sort -u
```

Expected: the 9 file names. After any later change, push again and repeat this check.

### 7. Run the Days

Follow [lab 3.01, 3 to 9](lab_transformation_3.01.md#3-how-to-run-the-job) with `VARIANT=b`, then
its [Validation](lab_transformation_3.01.md#validation).

## Questions

1. The log line must also show the batch start. How many files do you change, and how do you make
   sure none is missed?
2. What do you gain by reading one table's script alone, compared with labs A and C?
3. When would one script per table still be the better choice?

## Cleanup

[Lab 3.01, Cleanup](lab_transformation_3.01.md#cleanup), with `VARIANT=b`.
