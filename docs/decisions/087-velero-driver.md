# D-087 — How the Scripts Drive Velero

Status: Accepted
Date: 2026-11-17
Phase: specs/05-lab-state-persistence

## Context

`down.sh` must create a backup, wait for it to complete and then delete the older backups
([D-080](080-backup-retention.md)); `up.sh` must restore the latest backup and wait before Argo CD
starts ([D-078](078-velero-installation-and-restore-order.md)). Velero is driven either by its
command line tool (CLI) or by creating its Kubernetes objects (`Backup`, `Restore`) with `kubectl`.
Deleting a backup with the CLI also deletes its bucket files and EBS snapshots; deleting the `Backup`
object with `kubectl` removes only the object, and Velero brings it back from the bucket. Today the
project needs no Velero tool on the user's machine (`HOW_TO_RUN.md` §2).

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. `velero` CLI on the user's machine (`backup create --wait`, `restore create --wait`, `backup delete`) | Best practice: the Velero docs use the CLI for backup, restore and delete | One command per action; one new prerequisite (`choco install velero`) | Same | Adds a row to `HOW_TO_RUN.md` §2 |
| B. `kubectl` applying `Backup`/`Restore` objects and waiting on their phase | Accepted practice: the Velero API types docs document `Backup` and `Restore` | No new tool; more lines; deleting needs a separate request object (not in the docs read) | Same | Meets all requirements |
| C. `kubectl exec` into the Velero pod and run its `velero` binary | No official best practice: no Velero doc describes it (checked basic install, backup and restore reference) | No new tool; relies on the image's contents (not verified) | Same | Meets all requirements |

## Decision

- **Recommended:** A, because it is the documented best practice and the only alternative whose
  delete is documented to remove the snapshots, which D-080 needs.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Velero: backup reference, deleting backups](https://velero.io/docs/main/backup-reference/)
- [Velero: how Velero works, object storage sync](https://velero.io/docs/main/how-velero-works/)
- [Velero: Backup API type](https://velero.io/docs/main/api-types/backup/)
- [Velero: Restore API type](https://velero.io/docs/main/api-types/restore/)
- [Velero: basic install, Windows (Chocolatey)](https://velero.io/docs/main/basic-install/)
- [Velero: restore reference](https://velero.io/docs/main/restore-reference/)
