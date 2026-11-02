# 02.09 — Lab02: Date Cursor: Specification

Status: Implemented
Phase: [02 — Transactional Ingestion](../plan.md)

## Design

A lab guide followed by the user in the Airbyte UI; the configuration is not saved
([D-021](../../../docs/decisions/021-airbyte-connection-ui-lab.md)). It shows that an incremental sync
by a date column brings each day's inserts and updates into bronze, **but not deletes**.

| Part | Configuration |
|---|---|
| **Source** `Postgres oltp (cursor)` | Host `postgres.postgres.svc.cluster.local`, port `5432`, database `source`, schema `oltp`, user `airbyte`, password `AIRBYTE_PG_PASSWORD` ([D-036](../../../docs/decisions/036-airbyte-database-user.md)); SSL mode `disable` (the source Postgres has no TLS); update method: the user-defined cursor option |
| **Destination** `S3 bronze oltp_cursor` | Bucket `eks-for-data-bronze-283429977024`, path `oltp_cursor` ([D-042](../../../docs/decisions/042-lab-bronze-layout.md)), region `us-east-1`, Parquet SNAPPY, no keys (IRSA, as in lab01) |
| **Connection** | All 8 `oltp` streams, **Incremental \| Append**, cursor `updated_at` ([D-028](../../../docs/decisions/028-lab02-cursor.md)), primary key from the table, schedule **Manual** |

Lab flow:

1. Create the source, the destination and the connection.
2. **Sync 1:** the full current state (about 1.37 million orders and 6 million line items).
3. Simulate a day ([3. Simulate a Day](../HOW_TO_RUN.md#3-simulate-a-day)).
4. **Sync 2:** only rows whose `updated_at` passed the cursor.
5. Check bronze in the DuckDB UI (files at `oltp_cursor/oltp/<table>/`, each sync identified by
   `_airbyte_extracted_at`): sync 2 holds the day's new orders, the closed line items and the
   changed dimensions; the customers deleted in Postgres are **still in bronze**, with nothing
   marking the delete (lab03, CDC, captures them).

Verified: the Airbyte Postgres source supports `TIMESTAMP_WITH_TIMEZONE` cursors (the type of
`updated_at`), and Airbyte recommends CDC "when you need a record of deletions". The connector
installed with Airbyte 2.4.0 is `source-postgres` 3.8.10; its spec (`spec` command) names the
update method **Scan Changes with User Defined Cursor** and lists SSL mode `disable`. Confirmed in the lab: the
connection test accepts `disable`; the Parquet path is
`oltp_cursor/oltp/<table>/` only with Destination Namespace **Source-defined**
(**Destination-defined** writes `oltp_cursor/<table>/`).

Side effect: the 02.08 CDC slot keeps WAL while lab02 runs (nothing reads it yet), capped at 2GB
([D-041](../../../docs/decisions/041-replication-slot-wal-limit.md)); lab03 recreates it with
`04-cdc-setup.sql`.

## Files

| File | Change |
|---|---|
| `specs/02-transactional-ingestion/lab02-cursor-ingestion.md` | Create: the lab guide, in the format of lab01 (link bar, prerequisites, source, destination, connection, sync 1, simulate a day, sync 2, DuckDB checks, clean up) |
| `specs/02-transactional-ingestion/HOW_TO_RUN.md` | Modify: section **5. Lab 02 — Date Cursor**, linking to the guide |
| `specs/02-transactional-ingestion/README.md` | Modify: 02.09 section with the manual checks |
| `specs/02-transactional-ingestion/plan.md` | Modify: step status |

## Verification Plan

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | Airbyte namespace reaches Postgres as `airbyte` | Temporary `postgres:18.6` pod in `airbyte`: `psql -h postgres.postgres.svc.cluster.local -U airbyte -d source -c 'SELECT count(*) FROM oltp.orders'` | The order count | Pass: 1,367,012 |
| 2 | Manual | Source and destination | Lab sections 2 and 3 | Both connection tests pass | Pass: confirmed by the user (after SSL mode `require` → `disable`) |
| 3 | Manual | Sync 1 | Lab section 4 | **Succeeded**; 8 streams | Pass: confirmed by the user |
| 4 | Automated | Sync 1 in bronze | DuckDB: row count per table under `oltp_cursor/oltp/` | Equal to the `oltp` counts at sync time | Pass: 8 tables equal (e.g., orders 1,367,012; lineitem 5,468,672), in `oltp_cursor/<table>/` (Destination-defined); after the switch to Source-defined, a full sync in `oltp_cursor/oltp/` with 1,370,148 orders = Postgres |
| 5 | Manual | Sync 2 after a simulated day | Lab sections 5 and 6 | **Succeeded**; far fewer records than sync 1 | Pass: confirmed by the user |
| 6 | Automated | Sync 2 content | DuckDB: rows of the second `_airbyte_extracted_at` per table, compared with `oltp` rows whose `updated_at` is after sync 1 | Equal (insert + update), with possible repeats at the cursor boundary (at-least-once) | Not shown: `oltp_cursor/oltp/` holds one sync per table (the namespace switch re-read everything after 5 simulated days); step closed by the user |
| 7 | Manual | Deletes not captured | Lab section 7, DuckDB UI: the customers deleted in Postgres, looked up in bronze | Still present, nothing marking the delete | Pass: confirmed by the user (bronze `oltp_cursor/oltp/` alone gives 0, for the same reason as check 6) |

## Teardown

In the Airbyte UI, delete the connection, the source and the destination; they also go with
Airbyte's database at [Turn Off](../../../HOW_TO_RUN.md#51-turn-off). The bronze files go with the
bucket at Turn Off; to drop them earlier:
`aws s3 rm s3://eks-for-data-bronze-283429977024/oltp_cursor/ --recursive`.
