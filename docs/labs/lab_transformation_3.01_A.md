[Labs](README.md) › [3.01](lab_transformation_3.01.md) › A

# Lab 3.01 A — Metadata-Driven Job

## Goal

Build the [lab 3.01](lab_transformation_3.01.md) job as one generic program driven by metadata: a
JSON file describes each table (columns, types, key, treatments), and the program applies it to
every table, with no table name in its code.

## Prerequisites

[Lab 3.01](lab_transformation_3.01.md) read up to [1](lab_transformation_3.01.md#1-choose-how-to-organize-the-code),
with its prerequisites done.

## Concepts

- **Two files, two roles:**

  | File | Role |
  |---|---|
  | `silver_tables_a.json` | Everything that differs per table: columns and types, key, extraction rules |
  | `bronze_to_silver_a.py` | The engine: reads the JSON, builds the `CREATE TABLE`, and runs the same steps for every table |

- **Treatments as rules:** a per-table treatment is a rule in the JSON, not code. This lab needs
  one kind of rule, `extract`: a regex group pulled out of a column into a new typed column. It
  covers `name_number` and the `orderpriority` split. Every table also gets the common treatments
  (trim, `_row_hash`, `_batch`, `_loaded_at`) from the engine.
- **The contract is declared once:** the engine builds the `CREATE TABLE` and the casts from the
  same JSON columns.
- **JSON, not YAML:** Python reads JSON with its standard library, so the Spark image needs no new
  package.
- **Implications:** adding a table, or a column, is a JSON change with no code change. A treatment
  that no rule kind covers (a lookup, a condition, a calculation) needs a new rule kind in the
  engine: the JSON slowly turns into a small language of its own, which is the usual limit of this
  approach.

## Steps

### 1. Write the Metadata

Create `pipelines/spark/silver_tables_a.json`. The columns are the
[Silver Contract](lab_transformation_3.01.md#silver-contract); `extract` holds the derived
columns.

```json
{
  "region": {
    "key": ["regionkey"],
    "columns": {"regionkey": "bigint", "name": "string", "comment": "string"},
    "extract": []
  },
  "nation": {
    "key": ["nationkey"],
    "columns": {"nationkey": "bigint", "name": "string", "regionkey": "bigint",
                "comment": "string"},
    "extract": []
  },
  "supplier": {
    "key": ["suppkey"],
    "columns": {"suppkey": "bigint", "name": "string", "address": "string",
                "nationkey": "bigint", "phone": "string", "acctbal": "decimal(15,2)",
                "comment": "string", "created_at": "date"},
    "extract": [
      {"column": "name_number", "from": "name", "pattern": "#(\\d+)$", "type": "int"}
    ]
  },
  "customer": {
    "key": ["custkey"],
    "columns": {"custkey": "bigint", "name": "string", "address": "string",
                "nationkey": "bigint", "phone": "string", "acctbal": "decimal(15,2)",
                "mktsegment": "string", "comment": "string", "created_at": "date"},
    "extract": [
      {"column": "name_number", "from": "name", "pattern": "#(\\d+)$", "type": "int"}
    ]
  },
  "part": {
    "key": ["partkey"],
    "columns": {"partkey": "bigint", "name": "string", "mfgr": "string", "brand": "string",
                "type": "string", "size": "int", "container": "string",
                "retailprice": "decimal(15,2)", "comment": "string"},
    "extract": []
  },
  "partsupp": {
    "key": ["partkey", "suppkey"],
    "columns": {"partkey": "bigint", "suppkey": "bigint", "availqty": "int",
                "supplycost": "decimal(15,2)", "comment": "string"},
    "extract": []
  },
  "orders": {
    "key": ["orderkey"],
    "columns": {"orderkey": "bigint", "custkey": "bigint", "orderstatus": "string",
                "totalprice": "decimal(15,2)", "orderdate": "date",
                "orderpriority": "string", "clerk": "string", "shippriority": "int",
                "comment": "string"},
    "extract": [
      {"column": "priority_number", "from": "orderpriority", "pattern": "^(\\d)-",
       "type": "int"},
      {"column": "priority_label", "from": "orderpriority", "pattern": "^\\d-(.+)$",
       "type": "string"}
    ]
  },
  "lineitem": {
    "key": ["orderkey", "linenumber"],
    "columns": {"orderkey": "bigint", "partkey": "bigint", "suppkey": "bigint",
                "linenumber": "int", "quantity": "decimal(15,2)",
                "extendedprice": "decimal(15,2)", "discount": "decimal(15,2)",
                "tax": "decimal(15,2)", "returnflag": "string", "linestatus": "string",
                "shipdate": "date", "commitdate": "date", "receiptdate": "date",
                "shipinstruct": "string", "shipmode": "string", "comment": "string"},
    "extract": []
  }
}
```

### 2. Write the Engine

Create `pipelines/spark/bronze_to_silver_a.py`. It runs the steps of
[lab 3.01, Concepts, Steps per table](lab_transformation_3.01.md#concepts) for each table in the
JSON.

**2.1 Arguments, metadata and Spark session.** The JSON sits next to the script, in
`/opt/spark/jobs`. `TECHNICAL` are the columns every table has besides its own.

```python
"""Writes each day's bronze rows to silver, driven by silver_tables_a.json (lab 3.01 A)."""
import json
import os
import sys
from datetime import datetime, timezone

from pyspark.sql import SparkSession, Window, functions as F

with open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "silver_tables_a.json")) as file:
    TABLES = json.load(file)
TECHNICAL = {"updated_at": "timestamp", "_airbyte_extracted_at": "timestamp",
             "_row_hash": "string", "_batch": "timestamp", "_loaded_at": "timestamp"}
FIRST_BATCH = datetime(1970, 1, 1, tzinfo=timezone.utc)
bronze, catalog, namespace, since, until = sys.argv[1:6]
loaded_at = datetime.now(timezone.utc)


def utc(text):
    """Parses a UTC timestamp such as 2026-11-12T14:00:00.000000Z."""
    return datetime.fromisoformat(text.replace("Z", "+00:00"))


spark = (
    SparkSession.builder.appName("bronze-to-silver-a")
    .config("spark.sql.catalog.lake.warehouse", catalog)
    .config("spark.sql.catalog.lake.credential",
            f"{os.environ['POLARIS_CLIENT_ID']}:{os.environ['POLARIS_CLIENT_SECRET']}")
    .getOrCreate()
)
spark.sql(f"CREATE NAMESPACE IF NOT EXISTS lake.{namespace}")
extracted = F.col("_airbyte_extracted_at")
```

**2.2 Declare the table.** The columns of the `CREATE TABLE` come from the JSON: the table's own,
the derived ones of its `extract` rules, and the technical ones.

```python
for name, spec in TABLES.items():
    target = f"lake.{namespace}.{name}"
    derived = {rule["column"]: rule["type"] for rule in spec["extract"]}
    declared = {**spec["columns"], **derived, **TECHNICAL}
    spark.sql(f"CREATE TABLE IF NOT EXISTS {target} "
              f"({', '.join(f'{c} {t}' for c, t in declared.items())}) "
              "USING iceberg PARTITIONED BY (_batch)")
```

**2.3 The run's rows and batch.** Watermark or interval, as in
[lab 3.01, Concepts](lab_transformation_3.01.md#concepts).

```python
    day = spark.read.parquet(f"{bronze}/{name}/")
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
```

**2.4 Cast, dedup and treat.** Cast to the JSON types (the bronze columns not listed are dropped),
keep the last state per key, trim text, take the row hash of the JSON `columns` (business columns
only, in their order), then apply the `extract` rules.

```python
    in_bronze = {**spec["columns"], "updated_at": "timestamp",
                 "_airbyte_extracted_at": "timestamp"}
    day = day.select([F.col(c).cast(t) for c, t in in_bronze.items()])
    latest = Window.partitionBy(*spec["key"]).orderBy(
        F.col("updated_at").desc(), extracted.desc())
    day = day.withColumn("_rank", F.row_number().over(latest)).where("_rank = 1").drop("_rank")
    day = day.select([F.trim(c).alias(c) if t == "string" else F.col(c) for c, t in day.dtypes])
    values = [F.coalesce(F.col(c).cast("string"), F.lit("\u0000")) for c in spec["columns"]]
    day = day.withColumn("_row_hash", F.sha2(F.concat_ws("\u001f", *values), 256))
    for rule in spec["extract"]:
        day = day.withColumn(
            rule["column"],
            F.regexp_extract(rule["from"], rule["pattern"], 1).cast(rule["type"]))
```

**2.5 Overwrite the batch and log.** Replace the partition `_batch = <batch start>`; read the rows
written (`added-records`) and replaced (`deleted-records`) from the summary of the snapshot just
committed, so Spark does not count the data. A key is missing from the summary when its count is
0, hence the `coalesce`.

```python
    (day.withColumn("_batch", F.lit(batch)).withColumn("_loaded_at", F.lit(loaded_at))
     .select(list(declared)).writeTo(target).overwrite(F.col("_batch") == F.lit(batch)))
    written, replaced = spark.sql(
        "SELECT coalesce(summary['added-records'], '0'), coalesce(summary['deleted-records'], '0') "
        f"FROM {target}.snapshots ORDER BY committed_at DESC LIMIT 1").first()
    print(f"silver {namespace}.{name}: since={bound} until={until} "
          f"written={written} replaced={replaced}")

spark.stop()
```

### 3. Add the Files to ConfigMap `spark-jobs`

In `pipelines/spark/kustomization.yaml`, add the two files under `files`:

```yaml
      - bronze_to_silver_a.py
      - silver_tables_a.json
```

### 4. Write the `SparkApplication`

Create `pipelines/spark/bronze-to-silver-a.yaml` with the content of
[lab 3.01, 2](lab_transformation_3.01.md#2-the-sparkapplication), with `<variant>` replaced by `a`
(two places: `name` and `mainApplicationFile`).

### 5. Push and Check the ConfigMap

```bash
git add pipelines/spark/bronze_to_silver_a.py
git add pipelines/spark/silver_tables_a.json
git add pipelines/spark/kustomization.yaml
git add pipelines/spark/bronze-to-silver-a.yaml
git commit -m "Add the bronze-to-silver job of lab 3.01 A"
git push
```

Argo CD syncs Application `spark-jobs` within about 3 minutes (or click **Refresh** in its UI).
Check that the two files reached the ConfigMap:

```bash
kubectl -n spark get configmap spark-jobs -o jsonpath='{.data}' | grep -o '"[a-z_]*_a\.\(py\|json\)"' | sort -u
```

Expected: the two file names. After any later change, push again and repeat this check.

### 6. Run the Days

Follow [lab 3.01, 3 to 9](lab_transformation_3.01.md#3-how-to-run-the-job) with `VARIANT=a`, then
its [Validation](lab_transformation_3.01.md#validation).

## Questions

1. What do you change to add a ninth table? And to add a column to `customer`?
2. Lab 3.02 checks that `mktsegment` holds one of 5 allowed values. What would the JSON and the
   engine need for that?
3. When does a metadata-driven job become harder to read than plain code?

## Cleanup

[Lab 3.01, Cleanup](lab_transformation_3.01.md#cleanup), with `VARIANT=a`.
