"""Creates the silver schema and tables in Polaris from create_objects.sql (lab create objects).

Argument: the Polaris catalog name (e.g., prod), reached in Spark as "lake".
"""
import os
import sys

from pyspark.sql import SparkSession

catalog = sys.argv[1]

# Polaris catalog as "lake"; credentials of the engines' principal from Secret polaris-credentials
spark = (
    SparkSession.builder.appName("create-objects")
    .config("spark.sql.catalog.lake.warehouse", catalog)
    .config("spark.sql.catalog.lake.credential",
            f"{os.environ['POLARIS_CLIENT_ID']}:{os.environ['POLARIS_CLIENT_SECRET']}")
    .getOrCreate()
)

# One statement at a time: drop comment lines, split on ";"
with open("/opt/spark/jobs/create_objects.sql") as f:
    text = "\n".join(line.rstrip("\n") for line in f if not line.strip().startswith("--"))
for statement in (s.strip() for s in text.split(";")):
    if statement:
        spark.sql(statement)
        print(f"done: {statement.splitlines()[0]}")

# What exists now, with the number of columns of each table
for row in spark.sql("SHOW TABLES IN lake.silver").collect():
    columns = len(spark.table(f"lake.silver.{row.tableName}").columns)
    print(f"object silver.{row.tableName}: columns={columns}")
spark.stop()
