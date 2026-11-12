[Labs](README.md) › 3.02

# Lab 3.02 — Silver to Gold, Day by Day

## Goal

Build the gold layer from the silver tables of [lab 3.01](lab_transformation_3.01.md): a star
schema (four dimensions and one fact table) and one monthly aggregate, ready for analysis. Each run
recomputes only what the new silver batches changed, and a rerun leaves gold unchanged. The code
continues the organization of [lab 3.01 C](lab_transformation_3.01_C.md): a contract per table, a
shared module, one entry point.

## Prerequisites

- [Lab 3.01 C](lab_transformation_3.01_C.md) done up to day 3, with its silver namespace, and its
  files in ConfigMap `spark-jobs` (this lab reuses `silver_common_c.py`).
- The DuckDB UI open, with the catalog attached as `lake` and Postgres as `source`, as in
  [lab 3.01, Validation](lab_transformation_3.01.md#validation).
- Git Bash in the repository root, with push access to `main`.

## Concepts

- **What belongs in gold:** dimensional modeling and aggregates, shaped for analysis and business
  questions. Silver keeps a validated copy of each record version; gold answers questions.
- **Star schema:** a fact table holds the measures of an event (here, one order line: quantity,
  price, revenue) and the keys of its dimensions; each dimension table holds the descriptive
  attributes of one entity (customer, supplier, part, date). Queries join the fact to the
  dimensions they need.
- **Grain:** what one row of a table represents. `fact_lineitem`: one order line, in its current
  state. Each dimension: one entity, in its current state. Every check starts from the grain.
- **Current state of a key:** silver holds one row per key per batch. Gold uses each key's latest
  version, the same rule as the dedup of 3.01 (`last_state` in `silver_common_c.py`, reused here).
- **SCD1 dimensions:** a dimension keeps only the current attributes, overwriting the old ones (SCD
  type 1, Slowly Changing Dimension). Keeping history comes in lab 3.12 (SCD2).
- **Natural keys:** the dimensions keep the source keys (`custkey`). Surrogate keys (keys generated
  by the warehouse) are needed only when a dimension keeps several versions of an entity (SCD2).
- **Two refresh methods:**

  | Method | Tables | How |
  |---|---|---|
  | Full rebuild | Dimensions and the aggregate | `overwrite(F.lit(True))`: one commit replaces every row, and the declared schema stays. Small tables; the simplest idempotent refresh |
  | Affected months | `fact_lineitem` | Recompute only the months of `orderdate` touched by new silver batches, and write them with `overwritePartitions()` |

- **Affected months:** a day adds new orders and changes the status of open ones, so it touches a
  few months. The job finds the orders in silver batches newer than gold's watermark, takes their
  months, and recomputes those months entirely from the current state in silver.
- **Dynamic partition overwrite:** `overwritePartitions()` replaces only the partitions present in
  the data written, and keeps the others. It is the batch overwrite of 3.01, with the partitions
  chosen by the data instead of a condition. With no data it commits nothing, so the job skips the
  write when no month is affected.
- **Hidden partitioning:** `fact_lineitem` is `PARTITIONED BY (months(orderdate))`. Iceberg derives
  the month from `orderdate`, so a query that filters on `orderdate` reads only the matching
  months, with no extra column to filter on.
- **Watermark:** each fact row carries in `_batch` the newest silver batch it was built from (the
  line's or its order's). The highest `_batch` in `fact_lineitem` is the watermark: silver batches
  after it are new. The first run has no watermark and builds every month.
- **Why the aggregate is rebuilt in full:** it groups by the customer's nation and segment, taken
  from `dim_customer`. A dimension change can move a customer's old orders to another group, in any
  month, so recomputing only the affected months would leave old months stale.
- **Revenue:** `net_revenue = extendedprice × (1 − discount)` and
  `charge = net_revenue × (1 + tax)`, both as `decimal(18,4)`, as in TPC-H.
- **Deletes:** customers deleted at the source stay in silver, so they stay in `dim_customer`. CDC
  fixes this in lab 3.10.

## Gold Contract

| Table | Grain | Refresh | Columns and types |
|---|---|---|---|
| `dim_date` | One calendar day, from the first order date to the last receipt date | Full rebuild | `date date, year int, quarter int, month int, day int, day_of_week int, month_start date` |
| `dim_customer` | One customer, current state | Full rebuild | `custkey bigint, name string, address string, phone string, acctbal decimal(15,2), mktsegment string, created_at date, nationkey bigint, nation_name string, regionkey bigint, region_name string, _row_hash string, _batch timestamp` |
| `dim_supplier` | One supplier, current state | Full rebuild | `suppkey bigint, name string, address string, phone string, acctbal decimal(15,2), created_at date, nationkey bigint, nation_name string, regionkey bigint, region_name string, _row_hash string, _batch timestamp` |
| `dim_part` | One part, current state | Full rebuild | `partkey bigint, name string, mfgr string, brand string, type string, size int, container string, retailprice decimal(15,2), _row_hash string, _batch timestamp` |
| `fact_lineitem` | One order line, current state | Affected months; `PARTITIONED BY (months(orderdate))` | `orderkey bigint, linenumber int, custkey bigint, partkey bigint, suppkey bigint, orderdate date, shipdate date, commitdate date, receiptdate date, orderstatus string, orderpriority string, linestatus string, returnflag string, shipmode string, quantity decimal(15,2), extendedprice decimal(15,2), discount decimal(15,2), tax decimal(15,2), net_revenue decimal(18,4), charge decimal(18,4), _batch timestamp` |
| `agg_sales_monthly` | One month × nation × market segment of the customer | Full rebuild | `month date, region_name string, nation_name string, mktsegment string, orders bigint, lineitems bigint, quantity decimal(18,2), net_revenue decimal(22,4)` |

Every table also has `_loaded_at timestamp`, the run's start time. `_row_hash` and `_batch` in the
dimensions are the silver row's.

## Steps

### 1. Write the Shared Module

Create `pipelines/spark/gold_common.py`. It reuses `last_state` (current state per key) and
`cast_to` (cast to the declared schema) from lab 3.01 C.

```python
"""Steps shared by every gold table (lab 3.02)."""
from pyspark.sql import functions as F

from silver_common_c import cast_to, last_state

SUMMARY = ("SELECT coalesce(summary['added-records'], '0'), "
           "coalesce(summary['deleted-records'], '0') "
           "FROM {}.snapshots ORDER BY committed_at DESC LIMIT 1")


def create_table(spark, target, columns, partition):
    """Declares the table: its columns and, if any, its partition."""
    partitioned = f" PARTITIONED BY ({partition})" if partition else ""
    spark.sql(f"CREATE TABLE IF NOT EXISTS {target} ({columns}, _loaded_at timestamp) "
              f"USING iceberg{partitioned}")


def current(spark, silver, table, key):
    """Current state of each key of a silver table: its latest version across the batches."""
    return last_state(spark.table(f"{silver}.{table}"), key)


def affected_months(spark, silver, watermark):
    """Months of orderdate touched by the silver batches after the watermark; None = all."""
    if watermark is None:
        return None
    newer = F.col("_batch") > F.lit(watermark)
    changed = (spark.table(f"{silver}.lineitem").where(newer).select("orderkey")
               .union(spark.table(f"{silver}.orders").where(newer).select("orderkey"))
               .distinct())
    return [row[0] for row in current(spark, silver, "orders", ["orderkey"])
            .join(changed, "orderkey")
            .select(F.trunc("orderdate", "month")).distinct().collect()]


def replace_all(spark, df, target):
    """Replaces every row in one commit; returns the rows written and replaced."""
    cast_to(df, spark.table(target).schema).writeTo(target).overwrite(F.lit(True))
    return spark.sql(SUMMARY.format(target)).first()


def replace_partitions(spark, df, target):
    """Replaces only the partitions present in df; returns the rows written and replaced."""
    cast_to(df, spark.table(target).schema).writeTo(target).overwritePartitions()
    return spark.sql(SUMMARY.format(target)).first()
```

`cast_to` selects the declared columns in their order and casts them, so a build function only has
to produce columns with the right names; extra columns are dropped.

### 2. Write the Table Specs

Create `pipelines/spark/gold_tables.py`. Each build function receives `src`, which gives the
current state of a silver table (`src.current`), a gold table already written in this run
(`src.gold`), and the affected months (`src.months`).

```python
"""Gold contract of each table: columns, partition, refresh and build (lab 3.02)."""
from pyspark.sql import functions as F


def geography(src):
    """Each nation with its region's name."""
    region = src.current("region", ["regionkey"]).select(
        "regionkey", F.col("name").alias("region_name"))
    return (src.current("nation", ["nationkey"])
            .select("nationkey", F.col("name").alias("nation_name"), "regionkey")
            .join(region, "regionkey"))


def dim_date(src):
    orders = src.current("orders", ["orderkey"]).agg(F.min("orderdate").alias("first"))
    lines = src.current("lineitem", ["orderkey", "linenumber"]).agg(
        F.max("receiptdate").alias("last"))
    days = orders.crossJoin(lines).select(F.explode(F.sequence("first", "last")).alias("date"))
    return days.select(
        "date", F.year("date").alias("year"), F.quarter("date").alias("quarter"),
        F.month("date").alias("month"), F.dayofmonth("date").alias("day"),
        F.dayofweek("date").alias("day_of_week"), F.trunc("date", "month").alias("month_start"))


def dim_customer(src):
    return src.current("customer", ["custkey"]).join(geography(src), "nationkey")


def dim_supplier(src):
    return src.current("supplier", ["suppkey"]).join(geography(src), "nationkey")


def dim_part(src):
    return src.current("part", ["partkey"])


def fact_lineitem(src):
    orders = src.current("orders", ["orderkey"]).select(
        "orderkey", "custkey", "orderdate", "orderstatus", "orderpriority",
        F.col("_batch").alias("_orders_batch"))
    if src.months is not None:
        orders = orders.where(F.trunc("orderdate", "month").isin(src.months))
    net = F.col("extendedprice") * (1 - F.col("discount"))
    return (src.current("lineitem", ["orderkey", "linenumber"]).join(orders, "orderkey")
            .withColumn("net_revenue", net.cast("decimal(18,4)"))
            .withColumn("charge", (net * (1 + F.col("tax"))).cast("decimal(18,4)"))
            .withColumn("_batch", F.greatest("_batch", "_orders_batch")))


def agg_sales_monthly(src):
    customers = src.gold("dim_customer").select(
        "custkey", "region_name", "nation_name", "mktsegment")
    return (src.gold("fact_lineitem").join(customers, "custkey")
            .groupBy(F.trunc("orderdate", "month").alias("month"),
                     "region_name", "nation_name", "mktsegment")
            .agg(F.countDistinct("orderkey").alias("orders"),
                 F.count("*").alias("lineitems"),
                 F.sum("quantity").alias("quantity"),
                 F.sum("net_revenue").alias("net_revenue")))


TABLES = {
    "dim_date": {
        "columns": "date date, year int, quarter int, month int, day int, day_of_week int, "
                   "month_start date",
        "partition": None, "refresh": "all", "build": dim_date,
    },
    "dim_customer": {
        "columns": "custkey bigint, name string, address string, phone string, "
                   "acctbal decimal(15,2), mktsegment string, created_at date, "
                   "nationkey bigint, nation_name string, regionkey bigint, region_name string, "
                   "_row_hash string, _batch timestamp",
        "partition": None, "refresh": "all", "build": dim_customer,
    },
    "dim_supplier": {
        "columns": "suppkey bigint, name string, address string, phone string, "
                   "acctbal decimal(15,2), created_at date, "
                   "nationkey bigint, nation_name string, regionkey bigint, region_name string, "
                   "_row_hash string, _batch timestamp",
        "partition": None, "refresh": "all", "build": dim_supplier,
    },
    "dim_part": {
        "columns": "partkey bigint, name string, mfgr string, brand string, type string, "
                   "size int, container string, retailprice decimal(15,2), "
                   "_row_hash string, _batch timestamp",
        "partition": None, "refresh": "all", "build": dim_part,
    },
    "fact_lineitem": {
        "columns": "orderkey bigint, linenumber int, custkey bigint, partkey bigint, "
                   "suppkey bigint, orderdate date, shipdate date, commitdate date, "
                   "receiptdate date, orderstatus string, orderpriority string, "
                   "linestatus string, returnflag string, shipmode string, "
                   "quantity decimal(15,2), extendedprice decimal(15,2), "
                   "discount decimal(15,2), tax decimal(15,2), "
                   "net_revenue decimal(18,4), charge decimal(18,4), _batch timestamp",
        "partition": "months(orderdate)", "refresh": "months", "build": fact_lineitem,
    },
    "agg_sales_monthly": {
        "columns": "month date, region_name string, nation_name string, mktsegment string, "
                   "orders bigint, lineitems bigint, quantity decimal(18,2), "
                   "net_revenue decimal(22,4)",
        "partition": None, "refresh": "all", "build": agg_sales_monthly,
    },
}
```

The order of `TABLES` is the run order: the dimensions and the fact are written before the
aggregate reads them.

### 3. Write the Entry Point

Create `pipelines/spark/silver_to_gold.py`. It takes three arguments: catalog, silver namespace (of
lab 3.01 C) and gold namespace.

```python
"""Builds the gold tables from the silver tables of lab 3.01 C (lab 3.02)."""
import os
import sys
from datetime import datetime, timezone
from types import SimpleNamespace

from pyspark.sql import SparkSession, functions as F

import gold_common as common
from gold_tables import TABLES

catalog, silver_ns, gold_ns = sys.argv[1:4]
loaded_at = datetime.now(timezone.utc)

spark = (
    SparkSession.builder.appName("silver-to-gold")
    .config("spark.sql.catalog.lake.warehouse", catalog)
    .config("spark.sql.catalog.lake.credential",
            f"{os.environ['POLARIS_CLIENT_ID']}:{os.environ['POLARIS_CLIENT_SECRET']}")
    .getOrCreate()
)
silver, gold = f"lake.{silver_ns}", f"lake.{gold_ns}"
spark.sql(f"CREATE NAMESPACE IF NOT EXISTS {gold}")
for name, table in TABLES.items():
    common.create_table(spark, f"{gold}.{name}", table["columns"], table["partition"])

watermark = spark.table(f"{gold}.fact_lineitem").agg(F.max("_batch")).first()[0]
months = common.affected_months(spark, silver, watermark)
src = SimpleNamespace(
    current=lambda table, key: common.current(spark, silver, table, key),
    gold=lambda table: spark.table(f"{gold}.{table}"),
    months=months,
)

for name, table in TABLES.items():
    target = f"{gold}.{name}"
    if table["refresh"] == "months" and months == []:
        written, replaced = "0", "0"
    else:
        df = table["build"](src).withColumn("_loaded_at", F.lit(loaded_at))
        write = common.replace_partitions if table["refresh"] == "months" else common.replace_all
        written, replaced = write(spark, df, target)
    scope = "all" if table["refresh"] == "all" or months is None else f"{len(months)} months"
    print(f"gold {gold_ns}.{name}: scope={scope} written={written} replaced={replaced}")

spark.stop()
```

### 4. Add the Files to ConfigMap `spark-jobs`

In `pipelines/spark/kustomization.yaml`, add the three files under `files`:

```yaml
      - silver_to_gold.py
      - gold_tables.py
      - gold_common.py
```

### 5. Write the `SparkApplication`

Create `pipelines/spark/silver-to-gold.yaml`. It is the
[lab 3.01 template](lab_transformation_3.01.md#2-the-sparkapplication) with another name, script and
arguments, without the two `spark.hadoop.fs.s3a` settings: gold reads and writes only Iceberg
tables, through the credentials Polaris vends.

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: silver-to-gold
  namespace: spark
spec:
  type: Python
  mode: cluster
  sparkVersion: 4.0.5
  image: ghcr.io/andrerosalopes/spark:4.0.5-iceberg1.12.0
  imagePullPolicy: Always
  mainApplicationFile: local:///opt/spark/jobs/silver_to_gold.py
  arguments:
    - "<catalog>"
    - "<silver>"
    - "<gold>"
  restartPolicy:
    type: Never
  sparkConf:
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

### 6. Push and Check the ConfigMap

```bash
git add pipelines/spark/silver_to_gold.py
git add pipelines/spark/gold_tables.py
git add pipelines/spark/gold_common.py
git add pipelines/spark/kustomization.yaml
git add pipelines/spark/silver-to-gold.yaml
git commit -m "Add the silver-to-gold job of lab 3.02"
git push
```

Argo CD syncs Application `spark-jobs` within about 3 minutes (or click **Refresh** in its UI).
Check that the three files reached the ConfigMap:

```bash
kubectl -n spark get configmap spark-jobs -o jsonpath='{.data}' | grep -o '"\(silver_to_gold\|gold_[a-z]*\)\.py"' | sort -u
```

Expected: the three file names. After any later change, push again and repeat this check.

### 7. How to Run the Job

Use the catalog and the silver namespace of lab 3.01 C, and choose a new namespace for gold:

```bash
CATALOG=<catalog>
SILVER=<silver namespace of lab 3.01 C>
GOLD=<gold namespace>
```

Every run below uses these four commands:

```bash
kubectl -n spark delete sparkapplication silver-to-gold --ignore-not-found
```

```bash
sed -e "s/<catalog>/$CATALOG/" -e "s/<silver>/$SILVER/" -e "s/<gold>/$GOLD/" pipelines/spark/silver-to-gold.yaml | kubectl apply -f -
```

```bash
kubectl -n spark get sparkapplication silver-to-gold -w
```

Wait for `COMPLETED` (Ctrl+C to stop watching), then read one line per table:

```bash
kubectl -n spark logs silver-to-gold-driver | grep "^gold"
```

### 8. Initial Load

Run the job ([7](#7-how-to-run-the-job)). Gold is empty, so there is no watermark. Expected: 6
lines with `scope=all` and `replaced=0`; `fact_lineitem` writes one row per order line in silver.

### 9. Day 4

1. Simulate a day: [phase 02 Run, 3. Simulate a Day](../../specs/02-transactional-ingestion/HOW_TO_RUN.md#3-simulate-a-day).
2. In the Airbyte UI, open the lab02 connection → **Sync now**. Wait for **Succeeded**.
3. Run the silver job of lab 3.01 C
   ([lab 3.01, 3](lab_transformation_3.01.md#3-how-to-run-the-job)) with `VARIANT=c`,
   `NAMESPACE=$SILVER`, `SINCE=watermark` and `UNTIL=none`.
4. Run the gold job ([7](#7-how-to-run-the-job)).

Expected: `fact_lineitem` with `scope=<n> months`, a few months (the new orders' month and the
months of the open orders whose status changed), and `replaced` > 0: the old rows of those months.
The other tables are rebuilt in full: `written` = their row count, `replaced` = the previous one.

### 10. Rerun the Gold Job

Run the gold job again, with no new silver batch. Expected: `fact_lineitem` with `scope=0 months
written=0 replaced=0`; the other tables with `written` = `replaced` (same rows rewritten).

## Validation

In the DuckDB UI, replace `<silver>` and `<gold>` with the namespaces.

1. **Grain of the fact:**

   ```sql
   SELECT (SELECT count(*) FROM lake.<gold>.fact_lineitem) AS fact_rows,
          (SELECT count(*) FROM (SELECT DISTINCT orderkey, linenumber
                                 FROM lake.<silver>.lineitem)) AS silver_lines,
          (SELECT count(*) FROM (SELECT orderkey, linenumber FROM lake.<gold>.fact_lineitem
                                 GROUP BY ALL HAVING count(*) > 1)) AS duplicates;
   ```

   Expected: `fact_rows` = `silver_lines`, and `duplicates` = 0.

2. **Every fact row finds its dimensions:**

   ```sql
   SELECT count(*) FILTER (WHERE c.custkey IS NULL) AS no_customer,
          count(*) FILTER (WHERE s.suppkey IS NULL) AS no_supplier,
          count(*) FILTER (WHERE p.partkey IS NULL) AS no_part,
          count(*) FILTER (WHERE d.date IS NULL) AS no_date
   FROM lake.<gold>.fact_lineitem f
   LEFT JOIN lake.<gold>.dim_customer c ON c.custkey = f.custkey
   LEFT JOIN lake.<gold>.dim_supplier s ON s.suppkey = f.suppkey
   LEFT JOIN lake.<gold>.dim_part p ON p.partkey = f.partkey
   LEFT JOIN lake.<gold>.dim_date d ON d.date = f.orderdate;
   ```

   Expected: 0 in all four.

3. **Revenue matches the source:** the latest month, in gold and in Postgres.

   ```sql
   WITH m AS (SELECT max(date_trunc('month', orderdate)) AS month
              FROM lake.<gold>.fact_lineitem)
   SELECT (SELECT sum(net_revenue) FROM lake.<gold>.fact_lineitem, m
           WHERE date_trunc('month', orderdate) = m.month) AS gold,
          (SELECT sum(l.extendedprice * (1 - l.discount))
           FROM source.oltp.lineitem l JOIN source.oltp.orders o USING (orderkey), m
           WHERE date_trunc('month', o.orderdate) = m.month) AS source;
   ```

   Expected: `gold` = `source` (nothing changed at the source since the last sync).

4. **The aggregate adds up to the fact:**

   ```sql
   SELECT count(*) AS months_off
   FROM (SELECT month, sum(net_revenue) AS agg
         FROM lake.<gold>.agg_sales_monthly GROUP BY month) a
   FULL JOIN (SELECT CAST(date_trunc('month', orderdate) AS DATE) AS month,
                     sum(net_revenue) AS fact
              FROM lake.<gold>.fact_lineitem GROUP BY 1) f USING (month)
   WHERE a.agg IS DISTINCT FROM f.fact;
   ```

   Expected: 0.

5. **An analytical query (in the spirit of TPC-H Q5):** revenue of the nations of Asia last year,
   from orders whose customer and supplier are in the same nation.

   ```sql
   SELECT c.nation_name, sum(f.net_revenue) AS revenue
   FROM lake.<gold>.fact_lineitem f
   JOIN lake.<gold>.dim_customer c ON c.custkey = f.custkey
   JOIN lake.<gold>.dim_supplier s ON s.suppkey = f.suppkey AND s.nationkey = c.nationkey
   JOIN lake.<gold>.dim_date d ON d.date = f.orderdate
   WHERE c.region_name = 'ASIA' AND d.year = year(current_date) - 1
   GROUP BY ALL ORDER BY revenue DESC;
   ```

   Expected: 5 lines, the 5 nations of Asia, by revenue.

6. **Contract and hidden partitioning:**

   ```sql
   DESCRIBE lake.<gold>.fact_lineitem;
   ```

   Expected: the columns of `fact_lineitem` in the [Gold Contract](#gold-contract), plus
   `_loaded_at`, with no month column: the partition is derived from `orderdate`.

## Questions

1. Why are the dimensions rebuilt in full, while the fact is rewritten by month?
2. A day changed the status of 200 open orders. How many months were rewritten, and why?
3. What would go wrong in `fact_lineitem` if gold used silver's rows without taking each key's
   current state?
4. Why is the aggregate rebuilt in full, even though the fact is incremental?
5. Why would natural keys stop working if `dim_customer` kept the history of each customer (SCD2)?

## Cleanup

Delete the finished job (it holds no CPU or memory, but blocks a new run with the same name):

```bash
kubectl -n spark delete sparkapplication silver-to-gold
```

The gold tables go with the silver bucket and the catalog at
[Turn Off](../../HOW_TO_RUN.md#51-turn-off). To start this lab over before then, use a new gold
namespace in [7](#7-how-to-run-the-job).
