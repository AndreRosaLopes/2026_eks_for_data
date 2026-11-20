[Labs](README.md) › Create Objects in Polaris

# Lab — Create the Silver Objects in Polaris

## Goal

Create, with Spark, the schema `silver` in the Polaris catalog and its 8 empty tables, with the
columns, types and partition of the [lab 3.01 Silver Contract](lab_transformation_3.01.md#silver-contract).
Creating the objects is a step of its own: the load labs then only write data.

## Prerequisites

1. [Lab 3.00 — Polaris Catalog Setup](lab_transformation_3.00.md) done: the catalog (here `prod`),
   the principal `engines`, and Secret `polaris-credentials` in `spark` and `duckdb`.
2. The Spark Operator and the job ConfigMap running, from the repository root in Git Bash:

   ```bash
   kubectl -n argocd get applications spark-operator spark-jobs
   ```

   Expected: both `Synced` and `Healthy`.

3. The DuckDB UI open with the catalog attached as `lake`. In a second Git Bash window, leave this
   loop running:

   ```bash
   while true; do kubectl -n duckdb port-forward deploy/duckdb 4213:4213; sleep 1; done
   ```

   Open `http://localhost:4213`. If `lake` is not attached in this session, run each statement in
   its own cell, in this order, with `prod` replaced by your catalog name:

   ```sql
   CREATE SECRET polaris (TYPE iceberg, CLIENT_ID getenv('POLARIS_CLIENT_ID'), CLIENT_SECRET getenv('POLARIS_CLIENT_SECRET'), OAUTH2_SERVER_URI 'http://polaris.polaris.svc.cluster.local:8181/api/catalog/v1/oauth/tokens', OAUTH2_SCOPE 'PRINCIPAL_ROLE:ALL');
   ```

   ```sql
   ATTACH 'prod' AS lake (TYPE iceberg, URI 'http://polaris.polaris.svc.cluster.local:8181/api/catalog', SECRET polaris, ACCESS_DELEGATION_MODE 'vended_credentials');
   ```

4. Git Bash in the repository root, with push access to `main`, and the `.env` variables loaded:

   ```bash
   set -a; source .env; set +a
   ```

## Concepts

- **Catalog → schema → table:** the Polaris catalog holds schemas, and each schema holds tables.
  Polaris and Iceberg call a schema a **namespace**; it is the same thing. In Spark SQL,
  `CREATE SCHEMA`, `CREATE DATABASE` and `CREATE NAMESPACE` are the same command. This lab uses
  "schema"; the Polaris CLI and some error messages say "namespace".
- **`lake`:** the local name that Spark and DuckDB give the Polaris catalog. In Spark, the
  `SparkApplication` declares the catalog `lake` (`spark.sql.catalog.lake`) and the script points it
  to the Polaris catalog passed as argument (`spark.sql.catalog.lake.warehouse`). So
  `lake.silver.customer` is the table `customer`, schema `silver`, catalog `prod`.
- **Iceberg DDL:** a data definition language (DDL) statement creates or changes an object.
  `USING iceberg` makes the table an Iceberg table; `PARTITIONED BY (_batch)` stores each load batch
  in its own folder, so a load can replace one batch without touching the others.
- **No primary key or surrogate key in silver:** Iceberg enforces no key. Keeping one row per key
  per batch is the load job's job (lab 3.01). Surrogate keys go only in gold
  ([Surrogate Keys in Iceberg Tables](../iceberg-surrogate-keys.md)).
- **Idempotent:** `IF NOT EXISTS` makes a second run change nothing. An existing table is changed
  with `ALTER TABLE` (schema evolution), never by running `CREATE` again.
- **Where the files go:** under the catalog's base location, one folder per table, such as
  `s3://eks-for-data-silver-283429977024/prod/silver/customer/`. A new table has only metadata; data
  files appear with the first write.
- **How the script reaches the pod:** the scripts in `pipelines/spark` become ConfigMap `spark-jobs`
  (`kustomization.yaml`), which Argo CD updates after a `git push`. The `SparkApplication`, started
  with `kubectl apply`, mounts it at `/opt/spark/jobs`.
- **Driver and executor:** DDL runs on the driver only, so the `SparkApplication` asks for a single
  executor.

## Steps

### 1. Write the DDL

Create `pipelines/spark/create_objects.sql`:

```sql
-- Silver schema and tables (lab 3.01 Silver Contract). Run by create_objects.py, one statement
-- at a time. Safe to run again: IF NOT EXISTS changes nothing that already exists.

CREATE SCHEMA IF NOT EXISTS lake.silver;

CREATE TABLE IF NOT EXISTS lake.silver.region (
  regionkey bigint, name string, comment string,
  updated_at timestamp, _airbyte_extracted_at timestamp, _row_hash string,
  _batch timestamp, _loaded_at timestamp)
USING iceberg PARTITIONED BY (_batch);

CREATE TABLE IF NOT EXISTS lake.silver.nation (
  nationkey bigint, name string, regionkey bigint, comment string,
  updated_at timestamp, _airbyte_extracted_at timestamp, _row_hash string,
  _batch timestamp, _loaded_at timestamp)
USING iceberg PARTITIONED BY (_batch);

CREATE TABLE IF NOT EXISTS lake.silver.supplier (
  suppkey bigint, name string, address string, nationkey bigint, phone string,
  acctbal decimal(15,2), comment string, created_at date,
  name_number int,
  updated_at timestamp, _airbyte_extracted_at timestamp, _row_hash string,
  _batch timestamp, _loaded_at timestamp)
USING iceberg PARTITIONED BY (_batch);

CREATE TABLE IF NOT EXISTS lake.silver.customer (
  custkey bigint, name string, address string, nationkey bigint, phone string,
  acctbal decimal(15,2), mktsegment string, comment string, created_at date,
  name_number int,
  updated_at timestamp, _airbyte_extracted_at timestamp, _row_hash string,
  _batch timestamp, _loaded_at timestamp)
USING iceberg PARTITIONED BY (_batch);

CREATE TABLE IF NOT EXISTS lake.silver.part (
  partkey bigint, name string, mfgr string, brand string, type string, size int,
  container string, retailprice decimal(15,2), comment string,
  updated_at timestamp, _airbyte_extracted_at timestamp, _row_hash string,
  _batch timestamp, _loaded_at timestamp)
USING iceberg PARTITIONED BY (_batch);

CREATE TABLE IF NOT EXISTS lake.silver.partsupp (
  partkey bigint, suppkey bigint, availqty int, supplycost decimal(15,2), comment string,
  updated_at timestamp, _airbyte_extracted_at timestamp, _row_hash string,
  _batch timestamp, _loaded_at timestamp)
USING iceberg PARTITIONED BY (_batch);

CREATE TABLE IF NOT EXISTS lake.silver.orders (
  orderkey bigint, custkey bigint, orderstatus string, totalprice decimal(15,2),
  orderdate date, orderpriority string, clerk string, shippriority int, comment string,
  priority_number int, priority_label string,
  updated_at timestamp, _airbyte_extracted_at timestamp, _row_hash string,
  _batch timestamp, _loaded_at timestamp)
USING iceberg PARTITIONED BY (_batch);

CREATE TABLE IF NOT EXISTS lake.silver.lineitem (
  orderkey bigint, partkey bigint, suppkey bigint, linenumber int,
  quantity decimal(15,2), extendedprice decimal(15,2), discount decimal(15,2),
  tax decimal(15,2), returnflag string, linestatus string, shipdate date, commitdate date,
  receiptdate date, shipinstruct string, shipmode string, comment string,
  updated_at timestamp, _airbyte_extracted_at timestamp, _row_hash string,
  _batch timestamp, _loaded_at timestamp)
USING iceberg PARTITIONED BY (_batch);
```

Each table has its contract columns, its derived columns (`name_number`, `priority_number`,
`priority_label`), and the same five technical columns: `updated_at` (source change time),
`_airbyte_extracted_at` (ingestion time), `_row_hash`, `_batch` and `_loaded_at`. Keep `;` out of
the comments: the script splits the file on it.

### 2. Write the Script

Create `pipelines/spark/create_objects.py`:

```python
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
```

### 3. Write the `SparkApplication`

Create `pipelines/spark/create-objects.yaml`. It is
[`dedup-orders.yaml`](../../pipelines/spark/dedup-orders.yaml) with another name, script and
argument, without the bronze settings, and with one executor. `<catalog>` stays as a placeholder,
filled in at run time ([5](#5-run-the-job)):

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: create-objects
  namespace: spark
spec:
  type: Python
  mode: cluster
  sparkVersion: 4.0.5
  image: ghcr.io/andrerosalopes/spark:4.0.5-iceberg1.12.0
  imagePullPolicy: Always
  mainApplicationFile: local:///opt/spark/jobs/create_objects.py
  arguments:
    - "<catalog>"
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
    instances: 1
    annotations:
      karpenter.sh/do-not-disrupt: "true"
    serviceAccount: spark
```

| Setting | Why |
|---|---|
| `mainApplicationFile` | The script, from ConfigMap `spark-jobs` mounted at `/opt/spark/jobs` |
| `arguments` | The Polaris catalog name, read by the script as `sys.argv[1]` |
| `spark.sql.catalog.lake.*` | Declares the catalog `lake` as Polaris's Iceberg REST catalog; tables' storage credentials vended by Polaris |
| `spark.redaction.regex` | Keeps the Polaris credential out of the Spark UI and logs |
| `envFrom: polaris-credentials` | Gives the driver `POLARIS_CLIENT_ID` and `POLARIS_CLIENT_SECRET` |
| `executor.instances: 1` | DDL runs on the driver; one executor is the minimum |

### 4. Add the Files to the ConfigMap and Push

In `pipelines/spark/kustomization.yaml`, add the two job files under `files:` and keep every other
line. The whole file, after the change (comments omitted):

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: spark
configMapGenerator:
  - name: spark-jobs
    files:
      - read_bronze_orders.py
      - dedup_orders.py
      - create_objects.py
      - create_objects.sql
generatorOptions:
  disableNameSuffixHash: true
```

`disableNameSuffixHash: true` keeps the ConfigMap's name exactly `spark-jobs`: without it,
Kustomize adds a suffix (`spark-jobs-7h2k9...`) and the `SparkApplication` does not find the
ConfigMap. `namespace: spark` puts it where the jobs run. More in
[How a Spark Job Gets Its Script](../spark-jobs-configmap.md).

Commit and push:

```bash
git add pipelines/spark/create_objects.sql
git add pipelines/spark/create_objects.py
git add pipelines/spark/create-objects.yaml
git add pipelines/spark/kustomization.yaml
git commit -m "Add job that creates the silver objects in Polaris"
git push
```

Argo CD updates the ConfigMap within about 3 minutes. Check that it has both files:

```bash
kubectl -n spark get configmap spark-jobs -o jsonpath='{.data}' | grep -o 'create_objects\.[a-z]*' | sort -u
```

Expected: `create_objects.py` and `create_objects.sql`.

### 5. Run the Job

Set the catalog name (replace `prod` with yours):

```bash
CATALOG=prod
```

Delete the previous run, if any (a finished `SparkApplication` stays in the cluster):

```bash
kubectl -n spark delete sparkapplication create-objects --ignore-not-found
```

Start it; `sed` fills in the catalog without editing the file:

```bash
sed "s/<catalog>/$CATALOG/" pipelines/spark/create-objects.yaml | kubectl apply -f -
```

Follow it until `COMPLETED` (Ctrl+C to stop watching):

```bash
kubectl -n spark get sparkapplication create-objects -w
```

Read the result:

```bash
kubectl -n spark logs create-objects-driver | grep -E "^(done|object)"
```

### 6. Run It Again

Repeat the four commands of [5](#5-run-the-job). Expected: the same output; `IF NOT EXISTS` leaves
the schema and the tables as they were.

## Validation

1. The job log, from [5](#5-run-the-job): 9 `done:` lines (the schema and 8 tables) and one
   `object` line per table:

   | Table | Columns |
   |---|---|
   | `region` | 8 |
   | `nation` | 9 |
   | `supplier` | 14 |
   | `customer` | 15 |
   | `part` | 14 |
   | `partsupp` | 10 |
   | `orders` | 16 |
   | `lineitem` | 21 |

2. In the DuckDB UI, the 8 tables:

   ```sql
   SELECT table_name FROM duckdb_tables() WHERE database_name = 'lake' AND schema_name = 'silver' ORDER BY table_name;
   ```

3. A table's columns and types, as in the contract:

   ```sql
   DESCRIBE lake.silver.customer;
   ```

4. The tables are empty:

   ```sql
   SELECT count(*) AS rows FROM lake.silver.orders;
   ```

   Expected: `0`.

5. The schema in Polaris, with the engine credentials:

   ```bash
   polaris --client-id "$POLARIS_CLIENT_ID" --client-secret "$POLARIS_CLIENT_SECRET" namespaces list --catalog "$CATALOG"
   ```

   Expected: `silver` listed. It needs the Polaris tunnel
   (`kubectl -n polaris port-forward svc/polaris 8181:8181`) in another window.

## Questions

1. Why create the tables before the first load, instead of letting the load job create them?
2. What does `IF NOT EXISTS` do on the second run?
3. How would you add a column to `customer` without losing its data?
4. Why does silver have no surrogate key?

## Cleanup

Keep the schema and the tables: the load labs write to them. To drop them, in a Spark SQL session
on the same catalog, drop each table with `DROP TABLE lake.silver.<table> PURGE` (`PURGE` also
deletes its files in S3), then the schema with `DROP SCHEMA lake.silver`.
