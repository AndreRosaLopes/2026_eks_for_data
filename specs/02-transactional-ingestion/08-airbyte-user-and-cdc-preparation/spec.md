# 02.08 — Airbyte User and CDC Preparation: Specification

Status: Approved
Phase: [02 — Transactional Ingestion](../plan.md)

## Design

1. **Password: `.env` → Secret → Postgres**, the same flow as the superuser
   ([D-036](../../../docs/decisions/036-airbyte-database-user.md) D,
   [D-031](../../../docs/decisions/031-source-postgres-password-from-env.md)):

   | Where | What |
   |---|---|
   | `.env` | `AIRBYTE_PG_PASSWORD`, generated with `openssl rand -hex 16` |
   | Secret `postgres-credentials` | New key `airbyte-password` (one more `--from-literal` in home HOW_TO_RUN §3.2) |
   | StatefulSet `env` | `AIRBYTE_PG_PASSWORD` from that key (`secretKeyRef`) |

2. **Postgres** (`platform/aws/postgres/postgres.yaml`):
   - Argument `-c max_slot_wal_keep_size=2GB`
     ([D-041](../../../docs/decisions/041-replication-slot-wal-limit.md)), next to `wal_level=logical`.
   - Init script `02-airbyte-user.sh` in the `postgres-init` ConfigMap, run by the official image
     only when the volume is empty, with the image's documented heredoc pattern:

     ```bash
     psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'EOSQL'
     \getenv pw AIRBYTE_PG_PASSWORD
     CREATE USER airbyte WITH LOGIN REPLICATION PASSWORD :'pw';
     GRANT pg_read_all_data TO airbyte;
     EOSQL
     ```

     `\getenv` (psql) reads the password from the environment; the quoted `'EOSQL'` stops the shell
     from expanding anything, so the password never appears in a command line or a file.
   - No `pg_hba` change: the image's `host all all all scram-sha-256` already matches logical
     replication connections, which name a database (the `replication` keyword only matches physical
     replication).

3. **CDC script** (`pipelines/tpch/04-cdc-setup.sql`), run with the DuckDB CLI
   ([D-043](../../../docs/decisions/043-pipeline-script-execution.md)) before lab03 and after any
   baseline rerun ([D-039](../../../docs/decisions/039-cdc-publication-and-slot-script.md)), one
   `postgres_execute` per statement, no password, safe to rerun:
   1. `ALTER TABLE ... REPLICA IDENTITY DEFAULT` on the 8 `oltp` tables
      ([D-040](../../../docs/decisions/040-cdc-publication-and-replica-identity.md)).
   2. Drop `airbyte_slot` if it exists, then `DROP PUBLICATION IF EXISTS airbyte_publication`.
   3. `CREATE PUBLICATION airbyte_publication FOR TABLE` with the 8 `oltp` tables.
   4. `SELECT pg_create_logical_replication_slot('airbyte_slot', 'pgoutput')`, after the
      publication, so every change decoded from the slot sees it.
   5. Summary: the slot (name, plugin, active) and the published tables.

   A rerun fails while Airbyte is connected to the slot (an active slot cannot be dropped).

4. **Applying it on the running environment** (one-time upgrade): the init script needs an empty
   volume, so the Postgres data is reloaded. Runbook: phase How to Run,
   [Upgrade a Running Environment for 02.08](../HOW_TO_RUN.md#upgrade-a-running-environment-for-0208).
   A new environment does not need it: home HOW_TO_RUN §3.2 creates the Secret with both keys, and
   the volume starts empty.

5. **Pages:** home `HOW_TO_RUN.md` §3.2 (generate `AIRBYTE_PG_PASSWORD`, `--from-literal=airbyte-password=...`)
   and §4 Access (user `airbyte` and its password command); phase `HOW_TO_RUN.md` section
   **4. CDC Setup** (command, when to run it, active-slot note); phase `README.md` 02.08 section.

## Files

| File | Change |
|---|---|
| `platform/aws/postgres/postgres.yaml` | Modify: `max_slot_wal_keep_size=2GB`, `AIRBYTE_PG_PASSWORD` env, `02-airbyte-user.sh` in the ConfigMap |
| `pipelines/tpch/04-cdc-setup.sql` | Create: replica identity, publication, slot, summary |
| `HOW_TO_RUN.md` | Modify: §3.2 and §4 |
| `specs/02-transactional-ingestion/HOW_TO_RUN.md` | Modify: section 4. CDC Setup |
| `specs/02-transactional-ingestion/README.md` | Modify: 02.08 section |
| `specs/02-transactional-ingestion/plan.md` | Modify: step status |

## Verification Plan

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | Secret key | Keys of `postgres-credentials` (no values) | `password` and `airbyte-password` | Pass: `airbyte-password`, `password` |
| 2 | Automated | Postgres settings | `SHOW wal_level; SHOW max_slot_wal_keep_size;` | `logical`; `2GB` | Pass: `logical`; `2GB` |
| 3 | Automated | Airbyte user | `\du airbyte`; membership in `pg_read_all_data` | `Replication`; member of `pg_read_all_data` | Pass: login, replication, member of `pg_read_all_data` (`\drg`; `\du` no longer lists memberships since Postgres 16) |
| 4 | Automated | Login and read-only | As `airbyte`, over TCP with the `.env` password: `SELECT count(*) FROM oltp.orders`, then an `INSERT` | Count returned; `INSERT` fails with `permission denied` | Pass: 1,367,012 orders; `permission denied for table region` |
| 5 | Automated | Publication and slot | Run `04-cdc-setup.sql`; `pg_publication_tables`, `pg_replication_slots` | 8 `oltp` tables; `airbyte_slot`, `pgoutput`, logical | Pass: 8 tables; `airbyte_slot`, `pgoutput, logical` |
| 6 | Automated | Rerunnable | Run `04-cdc-setup.sql` again | Same result, still 1 slot | Pass: 1 slot, 8 tables |
| 7 | Automated | Replica identity | `relreplident` of the 8 tables | `d` for all 8 | Pass: `d` for all 8 |
| 8 | Manual | CDC objects | Run [4. CDC Setup](../HOW_TO_RUN.md#4-cdc-setup), then in [`psql`](../../../HOW_TO_RUN.md#45-source-postgres): `\du airbyte`, `SELECT slot_name, plugin FROM pg_replication_slots;`, `SELECT tablename FROM pg_publication_tables;` | `airbyte` with `Replication`; `airbyte_slot` / `pgoutput`; the 8 `oltp` tables | Pending |

## Teardown

- Publication and slot: `SELECT pg_drop_replication_slot('airbyte_slot'); DROP PUBLICATION airbyte_publication;`
  (drop the slot when lab03 is no longer used).
- Everything goes with the Postgres volume at [Turn Off](../../../HOW_TO_RUN.md#51-turn-off).
