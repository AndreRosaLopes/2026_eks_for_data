[How to Run](../../HOW_TO_RUN.md) › 02 — Transactional Ingestion: [Run](HOW_TO_RUN.md) | [Verify](README.md)

# Lab 00 — TPC-H Generation

Load the source Postgres with TPC-H data and build from it the `oltp` schema that labs 02 and 03
read. TPC-H is a standard benchmark dataset of orders, line items and customers
([D-024](../../docs/decisions/024-tpch-dataset-and-scale.md)); DuckDB generates it with `dbgen` and
writes it to Postgres. The data lives on the Postgres volume, which is deleted at teardown: repeat
this lab in every new environment, before lab 02 or lab 03.

## Prerequisites

- The environment up: Argo CD shows `postgres` and `duckdb` **Synced** and **Healthy**
  ([How to Run, 3. Bring Up](../../HOW_TO_RUN.md#3-bring-up)).
- Git Bash in the repository root.

The scripts run with the DuckDB CLI inside the DuckDB pod
([D-043](../../docs/decisions/043-pipeline-script-execution.md)).

## 1. Generate TPC-H

Run [1. Generate TPC-H](HOW_TO_RUN.md#1-generate-tpc-h) (about 1 minute). The script generates the
8 TPC-H tables at scale factor 1 in DuckDB memory and copies them to the `tpch` schema of Postgres.

Expected: the script ends with the row count of each table:

| Table | Rows |
|---|---|
| `region` | 5 |
| `nation` | 25 |
| `supplier` | 10,000 |
| `customer` | 150,000 |
| `part` | 200,000 |
| `partsupp` | 800,000 |
| `orders` | 1,500,000 |
| `lineitem` | 6,001,215 |

## 2. Build the OLTP Baseline

Run [2. OLTP Baseline](HOW_TO_RUN.md#2-oltp-baseline) (about 2 minutes). The script copies to the
`oltp` schema the orders up to the cutoff date (`1997-12-31`), with every date shifted so the cutoff
becomes yesterday ([D-025](../../docs/decisions/025-event-date-control.md)); later orders stay in
`tpch` for the daily simulation.

Expected: the script ends with one summary row:

| Column | Value |
|---|---|
| `orders` | 1,366,377 |
| `first_order` | About six years before yesterday |
| `last_order` | Yesterday |
| `open_orders` | About 18,000 (the orders of the last 30 days) |

## 3. Explore in the DuckDB UI (Optional)

Open the [DuckDB UI](../../HOW_TO_RUN.md#46-duckdb-ui) and run:

```sql
FROM source.oltp.orders SELECT orderstatus, count(*) AS orders GROUP BY orderstatus;
```

Expected: `F` (closed) with about 1,348,000 orders and `O` (open) with about 18,000.

## Next

- [Lab 02 — Date Cursor Ingestion](lab02-cursor-ingestion.md)
- [Lab 03 — CDC Ingestion](lab03-cdc-ingestion.md), after [4. CDC Setup](HOW_TO_RUN.md#4-cdc-setup)

Running this lab again replaces `tpch` and resets `oltp`; the daily simulation restarts from
yesterday.
