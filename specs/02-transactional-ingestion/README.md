# 02 — Transactional Ingestion: TPC-H in Postgres, Cursor and CDC: How to Verify

A source Postgres and a DuckDB service run on the phase 01 cluster, and Airbyte ingests the
transactional data into the S3 bronze bucket by date cursor and by CDC. Each step below is verified
on its own; the end-to-end verification proves the phase [Done When](plan.md#done-when).

## Prerequisites

- The [phase 01 prerequisites](../01-ingestion-airbyte-s3/README.md#prerequisites)

## Access

- **Repository files:** opened in the editor or on GitHub; no credentials needed.
- **Source Postgres password:** `POSTGRES_PASSWORD` in your local `.env`, sent to the cluster as the
  Secret `postgres-credentials` ([HOW_TO_RUN section 2](../../HOW_TO_RUN.md#2-services-with-argo-cd)).
  Recommended generation (32 hexadecimal characters):

  ```bash
  echo "POSTGRES_PASSWORD=$(openssl rand -hex 16)" >> .env
  ```

  To read it back from the cluster:

  ```bash
  kubectl -n postgres get secret postgres-credentials -o jsonpath='{.data.password}' | base64 -d
  ```

- **DuckDB Quack token:** `QUACK_TOKEN` in your local `.env`, sent to the cluster as the Secret
  `duckdb-credentials` ([HOW_TO_RUN section 2](../../HOW_TO_RUN.md#2-services-with-argo-cd)).
- **DuckDB UI, inside the DuckDB pod** (main path,
  [D-033](../../docs/decisions/033-duckdb-service-configuration.md)): nothing to install; the source
  Postgres is already attached as `source` and the bronze bucket is readable.

  ```bash
  kubectl -n duckdb port-forward deploy/duckdb 4213:4213
  ```

  Then open `http://localhost:4213`. The local port must be 4213: the UI accepts only requests from
  `http://localhost:4213`, and any other port fails with "Offset is outside the bounds of the
  DataView" (reload with Ctrl+Shift+R after fixing it).
- **DuckDB UI on your computer** (alternative, not verified in this phase): install the
  [DuckDB 2.0 CLI](https://duckdb.org/install/), forward the Quack port, and start the UI:

  ```bash
  kubectl -n duckdb port-forward svc/duckdb 9494:9494
  ```

  ```bash
  duckdb -ui
  ```

  In the UI, attach the server with the token from `.env`. `localhost` uses plain HTTP, and AWS
  queries such as `glob('s3://...')` run on your computer, not on the server:

  ```sql
  CREATE SECRET (TYPE quack, TOKEN '<QUACK_TOKEN>');
  ATTACH 'quack:localhost:9494' AS remote;
  ```

## Step Verification

### 02.01 — Roadmap and Architecture

1. Open the project `README.md`, section **2. Target Architecture**.
   - Expected result: the rows "Source database (simulated OLTP) | PostgreSQL" and
     "Data generation and exploration | DuckDB".
2. In the same file, section **3. Phases**, compare it with [plan.md](plan.md).
   - Expected result: 02 is **Transactional ingestion**, 03 is **Processing and transformation:**
     Trino and dbt, and 04 is **Orchestration:** Airflow.

### 02.02 — Source Database

1. Read the password from the cluster and compare it with `POSTGRES_PASSWORD` in your `.env`:

   ```bash
   kubectl -n postgres get secret postgres-credentials -o jsonpath='{.data.password}' | base64 -d
   ```

   - Expected result: the same value.
2. List the schemas of the `source` database:

   ```bash
   kubectl -n postgres exec postgres-0 -- psql -U postgres -d source -c '\dn'
   ```

   - Expected result: `oltp`, `public` and `tpch`.
3. Check logical replication:

   ```bash
   kubectl -n postgres exec postgres-0 -- psql -U postgres -d source -c 'SHOW wal_level'
   ```

   - Expected result: `logical`.

### 02.03 — DuckDB Service

1. Open the DuckDB UI inside the pod (see [Access](#access)):

   ```bash
   kubectl -n duckdb port-forward deploy/duckdb 4213:4213
   ```

   Then open `http://localhost:4213` (the local port must be 4213; see [Access](#access)).
   - Expected result: the DuckDB UI loads.
2. In a new cell, list the databases:

   ```sql
   FROM duckdb_databases();
   ```

   - Expected result: `source` among the databases.
3. List the schemas of the source Postgres:

   ```sql
   SELECT schema_name FROM source.information_schema.schemata;
   ```

   - Expected result: `oltp` and `tpch` among the schemas.

## Teardown

- [02.01](01-roadmap-and-architecture/spec.md#teardown): not applicable
- [02.02](02-source-database/spec.md#teardown): covered by phase 01 Turn Off
- [02.03](03-duckdb-service/spec.md#teardown): covered by phase 01 Turn Off
