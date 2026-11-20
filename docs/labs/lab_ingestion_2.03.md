[Labs](README.md) › 2.03

# Lab 2.03 — CDC Setup on Postgres

## Goal

Prepare the source Postgres for Change Data Capture (CDC) by Airbyte: a publication that lists the
8 `oltp` tables, and a replication slot that keeps their changes until Airbyte reads them. This lab
covers only the Postgres side; the Airbyte source and connection come in the CDC ingestion lab.

## Prerequisites

1. [Lab 2.02 — OLTP Baseline and Day Simulation](lab_ingestion_2.02.md) done: `oltp` has the 8
   tables.
2. Postgres and DuckDB running, from the repository root in Git Bash:

   ```bash
   kubectl -n argocd get applications postgres duckdb
   ```

   Expected: both `Synced` and `Healthy`.

3. The DuckDB UI open. In a second Git Bash window, leave this loop running:

   ```bash
   while true; do kubectl -n duckdb port-forward deploy/duckdb 4213:4213; sleep 1; done
   ```

   Open `http://localhost:4213`. The local port must be 4213. The tunnel often drops
   (`lost connection to pod`): the loop reconnects it, then reload the page.

4. No Airbyte sync connected to the slot `airbyte_slot`. If a CDC connection exists, stop its sync
   first: the script drops the slot, which fails while a sync is using it.

## Concepts

- **CDC (Change Data Capture):** reading every insert, update and delete from the database's log,
  instead of querying the tables. Unlike a date cursor, it also captures deletes.
- **WAL (Write-Ahead Log):** the log where Postgres writes every change before applying it to the
  tables. CDC reads it.
- **Logical replication:** Postgres decodes the WAL into row changes (table, operation, values).
  It requires `wal_level=logical`, set in the Postgres manifest (`platform/aws/postgres/postgres.yaml`).
- **`pgoutput`:** Postgres' built-in plugin that does this decoding; Airbyte reads its output.
- **Publication:** the list of tables whose changes are published, here `airbyte_publication`
  with the 8 `oltp` tables ([D-040](../decisions/040-cdc-publication-and-replica-identity.md)).
- **Replication slot:** a bookmark in the WAL for one reader, here `airbyte_slot`. Postgres keeps
  every WAL change from the slot's position until the reader confirms it, so nothing is lost
  between syncs ([D-039](../decisions/039-cdc-publication-and-slot-script.md)).
- **WAL limit:** a slot nobody reads keeps WAL forever and can fill the 10 GB Postgres disk.
  `max_slot_wal_keep_size=2GB` in the same manifest caps it: past 2 GB, Postgres invalidates the
  slot instead of filling the disk, and CDC must start over with a new slot
  ([D-041](../decisions/041-replication-slot-wal-limit.md)).
- **`REPLICA IDENTITY`:** what the WAL keeps of the old row on an update or delete. `DEFAULT`
  keeps only the primary key, which is enough because every `oltp` table has one.
- **The `airbyte` user:** created by Postgres on its first start, with `LOGIN`, `REPLICATION` (may
  read the WAL) and the built-in role `pg_read_all_data` (may read every table)
  ([D-036](../decisions/036-airbyte-database-user.md)). Nothing to create in this lab.

## Steps

### 1. Read the Script

Open `pipelines/tpch/04-cdc-setup.sql`:

1. Sets `REPLICA IDENTITY DEFAULT` on the 8 `oltp` tables.
2. Drops the slot `airbyte_slot` (if it exists), then the publication `airbyte_publication`, so
   every run starts clean.
3. Creates the publication with the 8 `oltp` tables.
4. Creates the slot with the `pgoutput` plugin. From here on, Postgres keeps WAL for it.
5. Ends with a summary of the slot and the published tables.

### 2. Run It

From the repository root (a few seconds):

```bash
MSYS_NO_PATHCONV=1 kubectl -n duckdb exec -i deploy/duckdb -- /duckdb < pipelines/tpch/04-cdc-setup.sql
```

Expected: no errors, and the summary lists `slot` `airbyte_slot` (`pgoutput, logical`) and
`publication` `airbyte_publication` with the 8 tables `oltp.customer`, `oltp.lineitem`,
`oltp.nation`, `oltp.orders`, `oltp.part`, `oltp.partsupp`, `oltp.region` and `oltp.supplier`.

## Validation

In the DuckDB UI, run each query in its own cell.

1. The `airbyte` user can replicate and read:

   ```sql
   FROM postgres_query('source', $$
   SELECT rolname, rolreplication, pg_has_role('airbyte', 'pg_read_all_data', 'MEMBER') AS reads_all
   FROM pg_roles WHERE rolname = 'airbyte'
   $$);
   ```

   Expected: `airbyte`, `true`, `true`.

2. Logical replication and the WAL limit are on:

   ```sql
   FROM postgres_query('source', $$
   SELECT name, setting, unit FROM pg_settings
   WHERE name IN ('wal_level', 'max_slot_wal_keep_size')
   $$);
   ```

   Expected: `wal_level` = `logical`; `max_slot_wal_keep_size` = `2048` with unit `MB`.

3. The slot and the WAL it holds:

   ```sql
   SELECT * FROM postgres_query('source', 'SELECT slot_name, plugin, active, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS wal_held FROM pg_replication_slots');
   ```

   Expected: `airbyte_slot`, `pgoutput`, `active` = `false` (no reader yet), and `wal_held` of a
   few kilobytes.

4. Simulate a day, from the repository root, then run query 3 again:

   ```bash
   MSYS_NO_PATHCONV=1 kubectl -n duckdb exec -i deploy/duckdb -- /duckdb < pipelines/tpch/03-simulate-day.sql
   ```

   Expected: `wal_held` grows, because nobody reads the slot yet.

## Questions

1. Why does the script drop the slot before the publication, and why does it fail while Airbyte is
   connected?
2. What happens to the slot if no sync reads it for many simulated days?
3. Why does rerunning the lab 2.02 baseline require running this lab again?
4. Why is `REPLICA IDENTITY DEFAULT` enough for the `oltp` tables?

## Cleanup

Keep the slot while you use CDC. When you stop using it, drop it so Postgres stops keeping WAL:

```sql
CALL postgres_execute('source', $$
SELECT pg_drop_replication_slot('airbyte_slot')
$$);
```

Running the script again recreates both: the slot then starts from that moment, and the WAL it held
until then is released.
