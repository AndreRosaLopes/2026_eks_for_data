# D-079 — Database Consistency at Backup Time

Status: Accepted
Date: 2026-11-17
Phase: specs/05-lab-state-persistence

## Context

A snapshot taken while Postgres is writing is only crash-consistent: on start, Postgres replays its
write-ahead log (WAL), as after a power loss. AKS docs: "Your applications may need to flush
writes-to-disk before you perform the snapshot operation."

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Cold backup: `down.sh` first deletes the `platform` Application (already its first step), so every Postgres shuts down cleanly and the PVCs remain; then Velero backs up | Strongest consistency: clean shutdown | Reorders `down.sh` only | Same | Meets all requirements; that Velero snapshots PVCs with no pod attached is not verified (checked in 05.03) |
| B. Hot backup with Velero pre-backup hooks running `CHECKPOINT` in each Postgres | Common practice | One hook annotation per database | Same | Meets all requirements |
| C. Hot, crash-consistent snapshot, no hooks | Accepted for Postgres: atomic snapshot plus WAL replay | Simplest | Same | Meets all requirements |

## Decision

- **Recommended:** A, because it gives a clean shutdown with no hooks, and `down.sh` already stops
  the services first.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [AKS: best practices for storage and backups](https://learn.microsoft.com/azure/aks/operator-best-practices-storage#secure-and-back-up-your-data)
- [Velero: CSI support](https://velero.io/docs/main/csi/)
