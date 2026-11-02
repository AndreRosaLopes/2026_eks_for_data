[How to Run](../../HOW_TO_RUN.md) › 01 — Ingestion: **Run** | [Verify](README.md)

# 01 — Ingestion: Airbyte Writing Parquet to S3: How to Run

What to execute in this phase, once the environment is up. The checks and expected results are in
[Verify](README.md).

## Prerequisites

- The environment up: [How to Run, 3. Bring Up](../../HOW_TO_RUN.md#3-bring-up); Argo CD shows
  `airbyte` **Synced** and **Healthy**.

## 1. Lab 01 — API Ingestion

Follow [Lab 01 — API Ingestion](lab01-api-ingestion.md): a connection created in the Airbyte UI
reads the PokeAPI and writes Parquet files to the S3 bronze bucket. The configuration is not saved
([D-021](../../docs/decisions/021-airbyte-connection-ui-lab.md)): repeat the lab in every new
environment.
