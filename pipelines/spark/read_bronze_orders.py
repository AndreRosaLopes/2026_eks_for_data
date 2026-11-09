"""Reads the bronze orders written by lab02 (date cursor) and prints two counts (step 03.04)."""
from pyspark.sql import SparkSession

BRONZE_ORDERS = "s3a://eks-for-data-bronze-283429977024/oltp_cursor/oltp/orders/"

spark = SparkSession.builder.appName("read-bronze-orders").getOrCreate()
orders = spark.read.parquet(BRONZE_ORDERS)
rows = orders.count()
keys = orders.select("orderkey").distinct().count()
print(f"bronze orders: rows={rows} distinct_orderkey={keys}")
spark.stop()
