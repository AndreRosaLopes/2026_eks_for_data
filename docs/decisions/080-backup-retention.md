# D-080 — Backup Retention

Status: Accepted
Date: 2026-11-17
Phase: specs/05-lab-state-persistence

## Context

Velero deletes expired backups (default TTL: 30 days) only while its server runs, in a loop that
runs every hour by default. With the cluster down most of the time, an expired backup could be
deleted right at bring-up, before or during its restore.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Latest only: a long TTL; after a new backup completes, `down.sh` deletes the older ones (`velero backup delete` also deletes their snapshots) | Explicit retention policy | Simplest; `up.sh` restores the only backup | Lowest: one set of snapshots | Meets all requirements |
| B. Named checkpoints (for example, one per lab); `up.sh` restores the latest or a named one | Explicit retention policy | A name argument, plus manual cleanup | Grows with each checkpoint (snapshots are incremental) | Meets all requirements |
| C. Velero default TTL (30 days) | Default | No setting | Low | Risk of a backup expiring at bring-up |

## Decision

- **Recommended:** A, because continuing where the lab stopped needs only the latest state.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Velero: how Velero works (TTL and garbage collection)](https://velero.io/docs/main/how-velero-works/)
