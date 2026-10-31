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

## Step Verification

### 02.01 — Roadmap and Architecture

1. Open the project `README.md`, section **2. Target Architecture**.
   - Expected result: the rows "Source database (simulated OLTP) | PostgreSQL" and
     "Data generation and exploration | DuckDB".
2. In the same file, section **3. Phases**, compare it with [plan.md](plan.md).
   - Expected result: 02 is **Transactional ingestion**, 03 is **Processing and transformation:**
     Trino and dbt, and 04 is **Orchestration:** Airflow.

## Teardown

- [02.01](01-roadmap-and-architecture/spec.md#teardown): not applicable
