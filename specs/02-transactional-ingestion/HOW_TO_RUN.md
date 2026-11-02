[How to Run](../../HOW_TO_RUN.md) › 02 — Transactional Ingestion: **Run** | [Verify](README.md)

# 02 — Transactional Ingestion: TPC-H in Postgres, Cursor and CDC: How to Run

What to execute in this phase, once the environment is up. The checks and expected results are in
[Verify](README.md).

## Prerequisites

- The environment up: [How to Run, 3. Bring Up](../../HOW_TO_RUN.md#3-bring-up); Argo CD shows
  `postgres` and `duckdb` **Synced** and **Healthy**.

The scripts in `pipelines/tpch/` run with the DuckDB CLI inside the DuckDB pod
([D-043](../../docs/decisions/043-pipeline-script-execution.md)), in the order below.
`MSYS_NO_PATHCONV=1` stops Git Bash from rewriting `/duckdb` into a Windows path. To explore the
data, use the [DuckDB UI](../../HOW_TO_RUN.md#46-duckdb-ui).

## 1. Generate TPC-H

[01-generate-tpch.sql](../../pipelines/tpch/01-generate-tpch.sql) writes TPC-H into the `tpch`
schema (about 1 minute). The scale factor is the line `SET VARIABLE sf = 1;` in the file. Running it
again replaces the tables.

```bash
MSYS_NO_PATHCONV=1 kubectl -n duckdb exec -i deploy/duckdb -- /duckdb < pipelines/tpch/01-generate-tpch.sql
```

## 2. OLTP Baseline

[02-oltp-baseline.sql](../../pipelines/tpch/02-oltp-baseline.sql) builds the `oltp` schema from
`tpch`, with dates shifted so the cutoff becomes yesterday (about 2 minutes). The cutoff is the line
`SET VARIABLE cutoff = '1997-12-31';` in the file; it accepts any date from `'1992-01-01'` (first
TPC-H order) to `'1998-08-02'` (last one, which loads every order and leaves none for the daily
simulation). Running it again resets `oltp`, and the simulation restarts from yesterday.

```bash
MSYS_NO_PATHCONV=1 kubectl -n duckdb exec -i deploy/duckdb -- /duckdb < pipelines/tpch/02-oltp-baseline.sql
```

## 3. Simulate a Day

[03-simulate-day.sql](../../pipelines/tpch/03-simulate-day.sql) advances `oltp` by one day (about 1
minute): new orders, line items shipping, and customer, supplier and part-supplier changes. Nothing
to edit; the amounts of dimension changes per day are the `SET VARIABLE` lines at the top. Run it
once per simulated day.

```bash
MSYS_NO_PATHCONV=1 kubectl -n duckdb exec -i deploy/duckdb -- /duckdb < pipelines/tpch/03-simulate-day.sql
```

## 4. CDC Setup

[04-cdc-setup.sql](../../pipelines/tpch/04-cdc-setup.sql) creates the publication (the 8 `oltp`
tables) and the replication slot `airbyte_slot` that Airbyte's CDC reads
([D-039](../../docs/decisions/039-cdc-publication-and-slot-script.md)). Run it before lab03 and
again after any rerun of [2. OLTP Baseline](#2-oltp-baseline), which drops the publication's
tables. It drops and recreates both, so it fails while Airbyte is connected to the slot: stop the
sync first. From then on, Postgres keeps WAL for the slot until Airbyte reads it (at most 2GB,
[D-041](../../docs/decisions/041-replication-slot-wal-limit.md)).

```bash
MSYS_NO_PATHCONV=1 kubectl -n duckdb exec -i deploy/duckdb -- /duckdb < pipelines/tpch/04-cdc-setup.sql
```

## Upgrade a Running Environment for 02.08

**Only once, and only for an environment brought up before step 02.08.** A new environment already
gets the Airbyte user from [How to Run, 3.2](../../HOW_TO_RUN.md#32-services-with-argo-cd).

Why: Postgres creates the `airbyte` user only on its first start, with an empty volume. So the
volume is recreated, and **the `tpch` and `oltp` data is lost and reloaded** (about 15 minutes in
total). Run every command in Git Bash, from the repository root, in one terminal.

**Step 1 — Create the password in `.env` and load it.**

```bash
echo "AIRBYTE_PG_PASSWORD=$(openssl rand -hex 16)" >> .env
```

```bash
set -a; source .env; set +a
```

Expected: no output. `.env` has a new line `AIRBYTE_PG_PASSWORD=...`.

**Step 2 — Add the password to the Postgres Secret.** The Secret already exists, so this replaces it
with both keys (`password` stays the same):

```bash
kubectl -n postgres create secret generic postgres-credentials --from-literal=password="$POSTGRES_PASSWORD" --from-literal=airbyte-password="$AIRBYTE_PG_PASSWORD" --dry-run=client -o yaml | kubectl apply -f -
```

Expected: `secret/postgres-credentials configured`.

**Step 3 — Push the new Postgres manifest and wait for Argo CD to apply it.** The setting
`max_slot_wal_keep_size=2GB` (and the `airbyte` user's init script) is in
[platform/aws/postgres/postgres.yaml](../../platform/aws/postgres/postgres.yaml), in the Postgres
`args`. Argo CD reads it from `main`, so the 02.08 commit must be pushed first (`git push`). Then
repeat this command until its output contains `max_slot_wal_keep_size=2GB` (up to about 3 minutes):

```bash
kubectl -n postgres get statefulset postgres -o jsonpath='{.spec.template.spec.containers[0].args}'; echo
```

Expected: `["-c","wal_level=logical","-c","max_slot_wal_keep_size=2GB"]`. If it still shows only
`wal_level=logical`, the commit is not on `main` yet, or Argo CD has not synced: open the
[Argo CD UI](../../HOW_TO_RUN.md#43-argo-cd) → `postgres` → **Refresh**.

In the Argo CD UI: `postgres` → click the **StatefulSet** `postgres` → **Live Manifest** tab → find
`args`. Expected: `max_slot_wal_keep_size=2GB`.

**Step 4 — Recreate Postgres with an empty volume (deletes the data).**

```bash
kubectl -n postgres delete pvc data-postgres-0 --wait=false
```

```bash
kubectl -n postgres delete pod postgres-0
```

```bash
kubectl -n postgres wait --for=condition=Ready pod/postgres-0 --timeout=10m
```

Expected: `persistentvolumeclaim "data-postgres-0" deleted`, `pod "postgres-0" deleted`, then
`pod/postgres-0 condition met` (1–3 minutes: a new EBS volume is created).

**Step 5 — Check that the `airbyte` user exists.**

```bash
kubectl -n postgres exec postgres-0 -- psql -U postgres -d source -c '\du airbyte'
```

```bash
kubectl -n postgres exec postgres-0 -- psql -U postgres -d source -c '\drg airbyte'
```

Expected: `airbyte` with `Replication`; then `airbyte` member of `pg_read_all_data` (since Postgres
16, `\du` no longer lists memberships, `\drg` does).

In the Argo CD UI: `postgres` → click the pod `postgres-0` → **Logs** tab → search for
`02-airbyte-user.sh`. Expected: `running /docker-entrypoint-initdb.d/02-airbyte-user.sh`, then
`CREATE ROLE` and `GRANT ROLE`.

**Step 6 — Reload the data and set up CDC:** run sections [1](#1-generate-tpc-h),
[2](#2-oltp-baseline), [3](#3-simulate-a-day) and [4](#4-cdc-setup) above, in order (about 6
minutes).
