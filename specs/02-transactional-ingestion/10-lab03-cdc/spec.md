# 02.10 — Lab03: CDC: Specification

Status: Approved
Phase: [02 — Transactional Ingestion](../plan.md)

## Design

A lab guide followed by the user in the Airbyte UI, in the format of lab02; the configuration is not
saved ([D-021](../../../docs/decisions/021-airbyte-connection-ui-lab.md)). It shows that CDC brings
each day's **inserts, updates and deletes** into bronze. Every check is manual: the guide holds each
command or DuckDB UI query with its expected result. The step also adds the phase end-to-end
walkthrough.

| Part | Configuration |
|---|---|
| **Before the lab** | Rerun [4. CDC Setup](../HOW_TO_RUN.md#4-cdc-setup): the slot has held WAL since 02.08 (581 MB at specification time, `wal_status` `reserved`), and the script recreates it empty |
| **Source** `Postgres oltp (CDC)` | As lab02 (host `postgres.postgres.svc.cluster.local`, database `source`, user `airbyte`, SSL mode `disable`, schema `oltp`); update method **Read Changes using Change Data Capture (CDC)**, Replication Slot `airbyte_slot`, Publication `airbyte_publication`; advanced fields at their defaults (LSN commit behavior "After loading Data in the destination", Initial Waiting Time 1200 s) |
| **Destination** `S3 bronze oltp_cdc` | As lab02, path `oltp_cdc` ([D-042](../../../docs/decisions/042-lab-bronze-layout.md)) |
| **Connection** | All 8 `oltp` streams, **Incremental \| Append**; cursor `_ab_cdc_lsn`, set by the source; primary key from the table. Configure connection as lab02: Destination Namespace **Source-defined** (files at `oltp_cdc/oltp/<table>/`), Propagate field changes only, notification and backfill off, schedule **Manual** |

Lab flow and sections:

1. **CDC setup:** run `04-cdc-setup.sql`; a DuckDB UI query shows the slot and the WAL it holds.
2. **Source** and 3. **Destination**.
4. **Connection and sync 1:** a snapshot of the current state; a DuckDB UI query compares the row
   counts of the 8 tables in bronze and in `oltp`.
5. **Simulate a day once, then sync 2:** one record per change read from the WAL;
   `_ab_cdc_updated_at` holds the change time and `_ab_cdc_deleted_at` is filled only on deletes.
6. **Check sync 2:** a DuckDB UI query per table: rows in sync 2, keys changed in Postgres since
   sync 1 (`updated_at` after the sync 1 snapshot), and changed keys missing from sync 2.
7. **Deletes are captured:** customers with `_ab_cdc_deleted_at` filled; the difference from lab02.
8. **Clean up:** the Airbyte objects are kept; dropping the slot is optional.

The phase README gets the **End-to-End Verification** of the plan "Done When", including a Git Bash
command that searches every tracked file for each `.env` value, printing only variable names.

Verified: the `spec` command of `source-postgres` 3.8.10 lists the CDC fields Replication Slot,
Publication, LSN commit behavior and the advanced fields with the defaults above; Airbyte's CDC docs
describe the columns `_ab_cdc_lsn`, `_ab_cdc_updated_at` and `_ab_cdc_deleted_at`, deletes arriving
as ordinary records, and Postgres 14 or later (the source runs 18.6); on the cluster,
`max_wal_senders` and `max_replication_slots` are 10.

## Files

| File | Change |
|---|---|
| `specs/02-transactional-ingestion/lab03-cdc-ingestion.md` | Create: the lab guide, with the queries and expected results of checks 1 and 3–7 |
| `specs/02-transactional-ingestion/HOW_TO_RUN.md` | Modify: section **6. Lab 03 — CDC**, linking to the guide |
| `specs/02-transactional-ingestion/lab02-cursor-ingestion.md` | Modify: the "Lab 03 — CDC" link in section 7 points to the new guide |
| `specs/02-transactional-ingestion/README.md` | Modify: 02.10 section; **End-to-End Verification** with the secrets check; 02.10 line in Teardown |
| `specs/02-transactional-ingestion/plan.md` | Modify: step status, then the plan to `Done` |
| `HOW_TO_RUN.md` | Modify: phase 02 row in "1. Phases" |

## Verification Plan

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Manual | Slot recreated | Lab section 1: CDC setup, then the slot query in the DuckDB UI | `airbyte_slot`, `pgoutput`, not active, a few kilobytes held; 8 `oltp` tables | Pending |
| 2 | Manual | Source and destination | Lab sections 2 and 3 | Both connection tests pass | Pending |
| 3 | Manual | Sync 1 | Lab section 4 | **Succeeded**; 8 streams | Pending |
| 4 | Manual | Sync 1 in bronze | Lab section 4, DuckDB UI: rows per table in `oltp_cdc/oltp/` and in `oltp` | `bronze` = `postgres` for the 8 tables | Pending |
| 5 | Manual | Sync 2 after one simulated day | Lab section 5 | **Succeeded**; thousands of records, not millions | Pending |
| 6 | Manual | Sync 2 content | Lab section 6, DuckDB UI: per table, rows in sync 2, keys changed in Postgres since sync 1, changed keys missing from bronze | `missing` = 0 for every table; rows ≥ changed keys (a row changed twice yields two records) | Pending |
| 7 | Manual | Deletes captured | Lab section 7, DuckDB UI: customers with `_ab_cdc_deleted_at` filled | `30` | Pending |
| 8 | Manual | No secrets in the repository | README End-to-End: Git Bash command searching every tracked file for each `.env` value, printing only variable names | `No secrets found` | Pending |
| 9 | Manual | Phase end-to-end | README **End-to-End Verification**: bring up → scripts 1–4 → lab02 → lab03 → Turn Off → Check Nothing Is Left | Each step as expected; nothing that costs is left | Pending |

## Teardown

| What | Action |
|---|---|
| Airbyte connections, sources and destinations (lab02 and lab03) | Kept; they go with Airbyte's database at [Turn Off](../../../HOW_TO_RUN.md#51-turn-off) |
| Slot `airbyte_slot` | Optional, after lab03 and with no sync running: drop it so it stops holding WAL ([02.08 Teardown](../08-airbyte-user-and-cdc-preparation/spec.md#teardown)). To use CDC again, rerun [4. CDC Setup](../HOW_TO_RUN.md#4-cdc-setup) and **Sync now** |
| Bronze files in `oltp_cdc/` | Go with the bucket at Turn Off; earlier: `aws s3 rm s3://eks-for-data-bronze-283429977024/oltp_cdc/ --recursive` |
