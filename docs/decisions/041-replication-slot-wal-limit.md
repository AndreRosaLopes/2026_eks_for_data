# D-041 — Replication Slot WAL Limit

Status: Accepted
Date: 2026-11-02
Phase: specs/02-transactional-ingestion

## Context

The replication slot keeps every WAL change until Airbyte reads it: between labs, when syncing
stops, or when `02-oltp-baseline.sql` reloads 6 million line items while the slot exists. The
Postgres volume is 10Gi; when it fills, Postgres stops.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. `max_slot_wal_keep_size=2GB` in the Postgres arguments | Postgres' own guard: past the limit the slot is invalidated instead of filling the disk; Airbyte documents the recovery (recreate the slot, resync) | One argument | None | Meets all requirements |
| B. No limit; drop the slot by hand when lab03 stops | Depends on remembering | Nothing to configure | None | A forgotten slot can stop Postgres |
| C. Bigger volume (e.g., 50Gi) | Delays the problem | One value | More EBS per hour | Meets all requirements |

## Decision

- **Recommended:** A, because it bounds the slot with Postgres' own setting, at no cost.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [PostgreSQL: `max_slot_wal_keep_size`](https://www.postgresql.org/docs/current/runtime-config-replication.html)
- [Airbyte: Postgres source (invalidated slots)](https://docs.airbyte.com/integrations/sources/postgres)
