# 05.04 — Backup on Teardown, Restore on Bring-Up: Specification

Status: Approved
Phase: [05 — Lab State Between Environments](../plan.md)

## Design

| Component | Configuration | ADR |
|---|---|---|
| Source, Polaris catalog and Airflow Postgres manifests | Namespace object removed; `up.sh` creates the namespace | [D-086](../../../docs/decisions/086-database-volumes-until-backup.md) |
| Same three StatefulSets | `whenDeleted: Retain` | [D-086](../../../docs/decisions/086-database-volumes-until-backup.md) |
| Velero CLI | New prerequisite in `HOW_TO_RUN.md` §2 | [D-087](../../../docs/decisions/087-velero-driver.md) |
| Velero CLI | Version 1.18.2, same as the server; a Chocolatey package for that version is not verified | [D-081](../../../docs/decisions/081-velero-version.md) |
| Backup scope | PVCs (disk requests) of `postgres`, `polaris`, `airflow`, `airbyte` | [D-076](../../../docs/decisions/076-lab-state-persistence.md) |
| Restore scope | PVCs only; other objects come from Argo CD and `up.sh` | [D-076](../../../docs/decisions/076-lab-state-persistence.md) |
| `down.sh` step 1 | Delete `platform`, as today; the databases shut down cleanly | [D-079](../../../docs/decisions/079-backup-consistency.md) |
| `down.sh` step 2 | Delete the `airbyte-db` StatefulSet (a Helm hook Argo CD may leave running); its PVC stays | [D-079](../../../docs/decisions/079-backup-consistency.md) |
| `down.sh` step 3 | `velero backup create --wait`; anything other than `Completed` stops `down.sh` before any deletion | [D-079](../../../docs/decisions/079-backup-consistency.md) |
| `down.sh` step 4 | Delete every older backup with `velero backup delete` | [D-080](../../../docs/decisions/080-backup-retention.md) |
| `down.sh` step 5 | Delete the four namespaces; their EBS volumes go with them | [D-086](../../../docs/decisions/086-database-volumes-until-backup.md) |
| `down.sh` step 6 | Destroy `gitops`, `backup`, `cluster`, as today | [D-077](../../../docs/decisions/077-persistent-data-root.md) |
| `up.sh` restore | After `backup` and the Secrets, before `gitops` | [D-078](../../../docs/decisions/078-velero-installation-and-restore-order.md) |
| `up.sh` restore | Waits for Velero to list the backups from the bucket | [D-078](../../../docs/decisions/078-velero-installation-and-restore-order.md) |
| `up.sh` restore | `velero restore create --wait` from the only backup; anything other than `Completed` stops `up.sh` | [D-080](../../../docs/decisions/080-backup-retention.md) |
| `up.sh` restore | No backup in the bucket: skipped (first bring-up, or after a purge) | [D-078](../../../docs/decisions/078-velero-installation-and-restore-order.md) |
| Purge | `down.sh --purge`: skips steps 3 and 4 | [D-088](../../../docs/decisions/088-purge-backup-deletion.md) |
| Purge | `velero backup delete --all`, waiting until no backup is left | [D-088](../../../docs/decisions/088-purge-backup-deletion.md) |
| Purge | Ends with `terraform destroy` on `infra/aws/data` | [D-082](../../../docs/decisions/082-persistent-bucket-deletion.md) |
| `HOW_TO_RUN.md` §3 and §5 | Describe the restore, the backup and the purge; the normal teardown keeps buckets and snapshots | Plan, Divergences |

Open points, checked in 05.05:

- The `auto-ebs-sc` StorageClass is created by Argo CD, after the restore; the restored PVCs are
  expected to wait for it, unbound (check 5).
- That a PVC-only restore is enough for CSI volumes is a reading of the Velero restore reference,
  not an explicit statement (check 7).

## Files

| File | Change |
|---|---|
| `platform/aws/postgres/postgres.yaml` | Modify: remove the Namespace; `whenDeleted: Retain` |
| `platform/aws/polaris-postgres/polaris-postgres.yaml` | Modify: same |
| `platform/aws/airflow-postgres/airflow-postgres.yaml` | Modify: same |
| `scripts/down.sh` | Modify: backup, retention, namespace deletion, `--purge` |
| `scripts/up.sh` | Modify: restore before `gitops` |
| `HOW_TO_RUN.md` | Modify: §2 Velero CLI; §3 restore; §5 backup, purge and what is kept |
| `specs/05-lab-state-persistence/plan.md` | Modify: Divergences notes that checks 3 to 9 of 05.04 run in 05.05 |

## Verification Plan

No manual check: by the user's decision, every test of this phase is automated and run by the agent
(plan, Scope). This step skips the "at least one Manual check" rule.

Checks 3 to 9 need a running environment: by the user's decision, they run in step 05.05, within
its `down.sh` and `up.sh` cycle, and their results are recorded here.

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | Scripts and manifests are valid | `bash -n` on both scripts; `kubectl apply --dry-run=client` on the three manifests | No errors | Pending |
| 2 | Automated | Manifests match the Design | Read the three manifests | No Namespace object; `whenDeleted: Retain` | Pending |
| 3 | Automated | First bring-up, no backup | `up.sh` | Restore skipped; every application `Synced` and `Healthy` | Deferred to 05.05 |
| 4 | Automated | Teardown backs up first | Write a marker row in each of the four databases; `down.sh`; `velero backup describe` before Velero goes | Backup `Completed`, with four volume snapshots | Deferred to 05.05 |
| 5 | Automated | After teardown, only data is left | `down.sh` final lists; EBS volumes and snapshots tagged `eks:eks-cluster-name=eks-for-data` | No cluster, NAT Gateway or VPC; no volume; four snapshots | Deferred to 05.05 |
| 6 | Automated | Bring-up restores before Argo CD | `up.sh`; compare the restore's completion time with the creation time of Argo CD's `platform` Application | Restore `Completed` earlier | Deferred to 05.05 |
| 7 | Automated | Data is back | Read the marker row in each of the four databases | Four markers found; applications `Synced` and `Healthy` | Deferred to 05.05 |
| 8 | Automated | Only the latest backup is kept | Second `down.sh`, then list the backups in the Velero bucket and the tagged snapshots | One backup; four snapshots | Deferred to 05.05 |
| 9 | Automated | Purge leaves nothing | `up.sh`, then `down.sh --purge`; list the `eks-for-data-*` buckets and tagged snapshots | Every list empty | Deferred to 05.05 |
| 10 | Automated | Docs match the scripts | Read `HOW_TO_RUN.md` §2, §3 and §5 | Velero CLI, restore, backup and purge described; no line says the normal teardown deletes the buckets | Pending |
| 11 | Automated | No secrets in the repository | `git grep` for each `.env` value | No match | Pending |

## Teardown

No resource incurs cost in this step: the checks that need an environment run in 05.05.
