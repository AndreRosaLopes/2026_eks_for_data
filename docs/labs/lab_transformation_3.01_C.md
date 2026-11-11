[Labs](README.md) › [3.01](lab_transformation_3.01.md) › C

# Lab 3.01 C — Per-Table Spec and Shared Module

## Goal

Build the [lab 3.01](lab_transformation_3.01.md) job with each table's contract and treatment in
code, one entry per table, and the steps every table shares written once in a shared module.

## Prerequisites

[Lab 3.01](lab_transformation_3.01.md) read up to [1](lab_transformation_3.01.md#1-choose-how-to-organize-the-code),
with its prerequisites done.

## Concepts

- **Three files, three roles:**

  | File | Role |
  |---|---|
  | `silver_tables_c.py` | What differs per table: declared columns, key, treatment function |
  | `silver_common_c.py` | What every table shares: create, read, cast, dedup, trim, write |
  | `bronze_to_silver_c.py` | Entry point: arguments, Spark session, loop over the tables |

- **The contract is declared once:** each table's columns are written in a `CREATE TABLE`. The job
  creates the table, then reads its schema back from the catalog to cast bronze to it, so there is
  no second list of types to keep in sync.
- **A treatment is a function:** it takes a DataFrame and returns one. It can be tested alone, with
  a local Spark and a few rows. A treatment used by more than one table (`name_number`) lives in the
  shared module.
- **Imports on the driver:** the driver runs `bronze_to_silver_c.py` from `/opt/spark/jobs`, and
  Python adds the script's folder to its import path, so the two other files are found there.
- **Implications:** adding a table is one entry in `silver_tables_c.py`; a fix to a common step is
  made once; a type change in the contract needs an `ALTER TABLE`, because `CREATE TABLE IF NOT
  EXISTS` does not change an existing table (lab 3.13).

## Steps

### 1. Write the Shared Module

Create `pipelines/spark/silver_common_c.py`:

```python
"""Steps shared by every silver table (lab 3.01 C)."""
from datetime import datetime, timezone

from pyspark.sql import Window, functions as F

FIRST_BATCH = datetime(1970, 1, 1, tzinfo=timezone.utc)
TECHNICAL = ("updated_at timestamp, _airbyte_extracted_at timestamp, "
             "_batch timestamp, _loaded_at timestamp")
EXTRACTED = F.col("_airbyte_extracted_at")


def utc(text):
    """Parses a UTC timestamp such as 2026-11-12T14:00:00.000000Z."""
    return datetime.fromisoformat(text.replace("Z", "+00:00"))


def create_table(spark, target, columns):
    """Declares the table: its columns, the technical columns, partitioned by batch."""
    spark.sql(f"CREATE TABLE IF NOT EXISTS {target} ({columns}, {TECHNICAL}) "
              "USING iceberg PARTITIONED BY (_batch)")


def read_batch(spark, path, target, since, until):
    """Returns the run's bronze rows, the lower bound and the batch start."""
    day = spark.read.parquet(path)
    if since == "watermark":
        bound = spark.table(target).agg(F.max(EXTRACTED)).first()[0]
        if bound is not None:
            day = day.where(EXTRACTED > F.lit(bound))
        batch = bound or FIRST_BATCH
    else:
        bound, batch = since, utc(since)
        day = day.where(EXTRACTED >= F.lit(batch))
    if until != "none":
        day = day.where(EXTRACTED < F.lit(utc(until)))
    return day, bound, batch


def cast_to(df, schema):
    """Keeps the declared columns found in bronze, cast to their declared types."""
    return df.select([F.col(f.name).cast(f.dataType) for f in schema if f.name in df.columns])


def last_state(df, key):
    """Keeps one row per key: the latest updated_at, ties broken by the ingestion time."""
    latest = Window.partitionBy(*key).orderBy(F.col("updated_at").desc(), EXTRACTED.desc())
    return df.withColumn("_rank", F.row_number().over(latest)).where("_rank = 1").drop("_rank")


def trim_text(df):
    """Trims every text column."""
    return df.select([F.trim(c).alias(c) if t == "string" else F.col(c) for c, t in df.dtypes])


def name_number(df):
    """Customer#000000001 -> 1."""
    return df.withColumn("name_number", F.regexp_extract("name", r"#(\d+)$", 1).cast("int"))


def write_batch(spark, df, target, batch, loaded_at):
    """Replaces the batch's partition; returns the rows written and replaced."""
    columns = spark.table(target).columns
    (df.withColumn("_batch", F.lit(batch)).withColumn("_loaded_at", F.lit(loaded_at))
     .select(columns).writeTo(target).overwrite(F.col("_batch") == F.lit(batch)))
    return spark.sql(
        "SELECT coalesce(summary['added-records'], '0'), coalesce(summary['deleted-records'], '0') "
        f"FROM {target}.snapshots ORDER BY committed_at DESC LIMIT 1").first()
```

`write_batch` reads the rows written (`added-records`) and replaced (`deleted-records`) from the
summary of the snapshot the overwrite just committed, so Spark does not count the data. A key is
missing from the summary when its count is 0, hence the `coalesce`.

### 2. Write the Table Specs

Create `pipelines/spark/silver_tables_c.py`. The columns are the
[Silver Contract](lab_transformation_3.01.md#silver-contract), with each table's derived columns.

```python
"""Silver contract of each oltp table: columns, key and treatment (lab 3.01 C)."""
from pyspark.sql import functions as F

from silver_common_c import name_number


def no_treatment(df):
    return df


def orders(df):
    """1-URGENT -> priority_number 1, priority_label URGENT."""
    return (df
            .withColumn("priority_number",
                        F.regexp_extract("orderpriority", r"^(\d)-", 1).cast("int"))
            .withColumn("priority_label",
                        F.regexp_extract("orderpriority", r"^\d-(.+)$", 1)))


TABLES = {
    "region": {
        "key": ["regionkey"],
        "columns": "regionkey bigint, name string, comment string",
        "treat": no_treatment,
    },
    "nation": {
        "key": ["nationkey"],
        "columns": "nationkey bigint, name string, regionkey bigint, comment string",
        "treat": no_treatment,
    },
    "supplier": {
        "key": ["suppkey"],
        "columns": "suppkey bigint, name string, address string, nationkey bigint, "
                   "phone string, acctbal decimal(15,2), comment string, created_at date, "
                   "name_number int",
        "treat": name_number,
    },
    "customer": {
        "key": ["custkey"],
        "columns": "custkey bigint, name string, address string, nationkey bigint, "
                   "phone string, acctbal decimal(15,2), mktsegment string, comment string, "
                   "created_at date, name_number int",
        "treat": name_number,
    },
    "part": {
        "key": ["partkey"],
        "columns": "partkey bigint, name string, mfgr string, brand string, type string, "
                   "size int, container string, retailprice decimal(15,2), comment string",
        "treat": no_treatment,
    },
    "partsupp": {
        "key": ["partkey", "suppkey"],
        "columns": "partkey bigint, suppkey bigint, availqty int, supplycost decimal(15,2), "
                   "comment string",
        "treat": no_treatment,
    },
    "orders": {
        "key": ["orderkey"],
        "columns": "orderkey bigint, custkey bigint, orderstatus string, "
                   "totalprice decimal(15,2), orderdate date, orderpriority string, "
                   "clerk string, shippriority int, comment string, "
                   "priority_number int, priority_label string",
        "treat": orders,
    },
    "lineitem": {
        "key": ["orderkey", "linenumber"],
        "columns": "orderkey bigint, partkey bigint, suppkey bigint, linenumber int, "
                   "quantity decimal(15,2), extendedprice decimal(15,2), "
                   "discount decimal(15,2), tax decimal(15,2), returnflag string, "
                   "linestatus string, shipdate date, commitdate date, receiptdate date, "
                   "shipinstruct string, shipmode string, comment string",
        "treat": no_treatment,
    },
}
```

### 3. Write the Entry Point

Create `pipelines/spark/bronze_to_silver_c.py`. It runs the steps of
[lab 3.01, Concepts, Steps per table](lab_transformation_3.01.md#concepts) for each table.

```python
"""Writes each day's bronze rows of the 8 oltp tables to silver Iceberg tables (lab 3.01 C)."""
import os
import sys
from datetime import datetime, timezone

from pyspark.sql import SparkSession

import silver_common_c as common
from silver_tables_c import TABLES

bronze, catalog, namespace, since, until = sys.argv[1:6]
loaded_at = datetime.now(timezone.utc)

spark = (
    SparkSession.builder.appName("bronze-to-silver-c")
    .config("spark.sql.catalog.lake.warehouse", catalog)
    .config("spark.sql.catalog.lake.credential",
            f"{os.environ['POLARIS_CLIENT_ID']}:{os.environ['POLARIS_CLIENT_SECRET']}")
    .getOrCreate()
)
spark.sql(f"CREATE NAMESPACE IF NOT EXISTS lake.{namespace}")

for name, table in TABLES.items():
    target = f"lake.{namespace}.{name}"
    common.create_table(spark, target, table["columns"])
    day, bound, batch = common.read_batch(spark, f"{bronze}/{name}/", target, since, until)
    day = common.cast_to(day, spark.table(target).schema)
    day = common.last_state(day, table["key"])
    day = table["treat"](common.trim_text(day))
    written, replaced = common.write_batch(spark, day, target, batch, loaded_at)
    print(f"silver {namespace}.{name}: since={bound} until={until} "
          f"written={written} replaced={replaced}")

spark.stop()
```

### 4. Add the Files to ConfigMap `spark-jobs`

In `pipelines/spark/kustomization.yaml`, add the three files under `files`:

```yaml
      - bronze_to_silver_c.py
      - silver_tables_c.py
      - silver_common_c.py
```

### 5. Write the `SparkApplication`

Create `pipelines/spark/bronze-to-silver-c.yaml` with the content of
[lab 3.01, 2](lab_transformation_3.01.md#2-the-sparkapplication), with `<variant>` replaced by `c`
(two places: `name` and `mainApplicationFile`).

### 6. Push and Check the ConfigMap

```bash
git add pipelines/spark/bronze_to_silver_c.py
git add pipelines/spark/silver_tables_c.py
git add pipelines/spark/silver_common_c.py
git add pipelines/spark/kustomization.yaml
git add pipelines/spark/bronze-to-silver-c.yaml
git commit -m "Add the bronze-to-silver job of lab 3.01 C"
git push
```

Argo CD syncs Application `spark-jobs` within about 3 minutes (or click **Refresh** in its UI).
Check that the three files reached the ConfigMap:

```bash
kubectl -n spark get configmap spark-jobs -o jsonpath='{.data}' | grep -o '"[a-z_]*_c\.py"' | sort -u
```

Expected: the three file names. After any later change, push again and repeat this check.

### 7. Run the Days

Follow [lab 3.01, 3 to 9](lab_transformation_3.01.md#3-how-to-run-the-job) with `VARIANT=c`, then
its [Validation](lab_transformation_3.01.md#validation).

## Questions

1. Where do you change the code to add a ninth table, and to fix a bug in the dedup?
2. Why does the job read the table's schema from the catalog instead of a list of types in the
   code?
3. How would you test the `orders` treatment without a cluster?

## Cleanup

[Lab 3.01, Cleanup](lab_transformation_3.01.md#cleanup), with `VARIANT=c`.
