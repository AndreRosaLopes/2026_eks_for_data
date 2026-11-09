"""Deduplicates the bronze orders (lab02) into an Iceberg table in Polaris (step 03.06).

Starting point for the lab: keeps one row per orderkey, the one with the latest updated_at, and
replaces the whole table on every run. The lab may change the rule or the write method (for
example, MERGE INTO). Arguments: catalog namespace table, all chosen in the lab.
"""
import os
import sys

from pyspark.sql import SparkSession, Window, functions as F

BRONZE_ORDERS = "s3a://eks-for-data-bronze-283429977024/oltp_cursor/oltp/orders/"
catalog, namespace, table = sys.argv[1:4]

# Polaris connection (D-044); credentials of the engines' principal from Secret
# polaris-credentials (D-062); silver credentials vended by Polaris (D-049)
spark = (
    SparkSession.builder.appName("dedup-orders")
    .config("spark.sql.catalog.lake.warehouse", catalog)
    .config("spark.sql.catalog.lake.credential",
            f"{os.environ['POLARIS_CLIENT_ID']}:{os.environ['POLARIS_CLIENT_SECRET']}")
    .getOrCreate()
)

orders = spark.read.parquet(BRONZE_ORDERS)
latest = Window.partitionBy("orderkey").orderBy(
    F.col("updated_at").desc(), F.col("_airbyte_extracted_at").desc())
silver = (
    orders.withColumn("_rank", F.row_number().over(latest))
    .where("_rank = 1")
    .drop("_rank", *[c for c in orders.columns if c.startswith("_airbyte")])
)

spark.sql(f"CREATE NAMESPACE IF NOT EXISTS lake.{namespace}")
silver.writeTo(f"lake.{namespace}.{table}").createOrReplace()

written = spark.table(f"lake.{namespace}.{table}")
print(f"silver {namespace}.{table}: rows={written.count()} "
      f"distinct_orderkey={written.select('orderkey').distinct().count()}")
spark.stop()
