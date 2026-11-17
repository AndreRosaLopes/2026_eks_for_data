# 05 — Lab State Between Environments: Plan

Status: Approved

## Objective

Stop the labs at any point and resume them later from that same point.

How it is planned: `down.sh` saves the state of every database and `up.sh` brings it back in the new
cluster, so a new environment no longer starts from zero. The S3 data (bronze, silver, Airbyte,
Airflow logs) survives the teardown. EKS, the NAT Gateways and the nodes are still destroyed, so the
cost stays near zero while the environment is down.

## Scope

- A Terraform root with its own lifecycle for the buckets (bronze, silver, Airbyte, Airflow, plus a
  Velero backup bucket), never destroyed by `down.sh`
- The `snapshot-controller` EKS add-on
- Velero with CSI snapshots of the four databases (source Postgres, Polaris catalog Postgres,
  Airflow Postgres, Airbyte database); Velero's IRSA role limited to S3
- A `VolumeSnapshotClass` with `deletionPolicy: Retain`, so the EBS snapshots survive the cluster
- `down.sh`: back up the databases, then tear down; `up.sh`: restore them before Argo CD starts the
  services
- A purge (full reset) that removes the buckets, backups and snapshots
- Every verification is automated and run by Claude: no manual UI step

## Out of Scope

- Backing up the content of the buckets (they persist)
- Restoring Kubernetes objects other than the volumes (Argo CD and `up.sh` recreate them; Secrets
  come from `.env`)
- Cross-region or cross-cloud backups (data movement)
- Scheduled backups
- Azure and GCP deployments
- CloudNativePG ([EVOLUTIONS.md](../../EVOLUTIONS.md), evolution 1)

## Done When

Every check is run automatically by Claude:

- After `down.sh` and `up.sh`, a marker row written before the teardown exists in each of the four
  databases
- The source Postgres has the same row count per TPC-H table, and its CDC replication slot exists
- Airbyte keeps its connections, and the next CDC sync reads only the changes made after the
  restore (no full resync)
- DuckDB reads `silver.orders` through Polaris with the same row count as before the teardown
- Airflow lists the DAG runs from before the teardown, and their task logs open
- After `down.sh`, only the buckets and the EBS snapshots are left; after the purge, nothing is left
- No secrets in the repository

## Decisions

- [D-076 — How Lab State Survives Teardown](../../docs/decisions/076-lab-state-persistence.md)
- [D-077 — Terraform Root Layout with a Persistent Data Root](../../docs/decisions/077-persistent-data-root.md)
- [D-078 — How Velero Is Installed and When the Restore Runs](../../docs/decisions/078-velero-installation-and-restore-order.md)
- [D-079 — Database Consistency at Backup Time](../../docs/decisions/079-backup-consistency.md)
- [D-080 — Backup Retention](../../docs/decisions/080-backup-retention.md)
- [D-081 — Velero Version](../../docs/decisions/081-velero-version.md)
- [D-082 — Deleting the Persistent Buckets on Purge](../../docs/decisions/082-persistent-bucket-deletion.md)
- [D-083 — S3 Module Version in the Data Root](../../docs/decisions/083-data-root-s3-module-version.md)
- [D-084 — Snapshot Controller Add-on Version](../../docs/decisions/084-snapshot-controller-addon-version.md)
- [D-085 — Where the VolumeSnapshotClass Is Defined](../../docs/decisions/085-volumesnapshotclass-location.md)

**Divergences (principle 7):**

- D-003 is superseded by D-077.
- `HOW_TO_RUN.md` §3 and §5 describe a teardown that deletes the buckets; updated in 05.04.
- README §3 has no phase 05 row; added in 05.01.
- The phase 01 to 04 plans say "The teardown removes every resource that incurs cost". From this
  phase on, the normal teardown keeps the buckets and snapshots (cents per month) and the purge
  removes everything; the earlier plans stay as their historical record.
- Checks 2 to 9 of 05.03 (they need a running environment) run in 05.05, by the user's decision.
- D-016 (bronze versioning off) gives as reason that bronze is lost on teardown, which no longer
  holds; it is not changed in this phase.

## Steps

| # | Step | Status |
|---|---|---|
| 05.01 | [Roadmap](01-roadmap/spec.md): README §3, the phase 05 row added from this plan | Done |
| 05.02 | [Persistent data root](02-persistent-data-root/spec.md): the four buckets move to `infra/aws/data`, plus the Velero bucket; `cluster` refers to them by name; `down.sh` keeps them; automated check that bronze and silver survive a teardown | Done |
| 05.03 | [Snapshot controller and Velero](03-snapshot-controller-velero/spec.md): the add-on, the Velero IRSA role, the `infra/aws/backup` root and the `VolumeSnapshotClass`; `up.sh` applies and `down.sh` destroys the `backup` root; automated backup and restore of a test volume | Done |
| 05.04 | Backup on teardown, restore on bring-up: `down.sh` (cold backup, keep the latest only), `up.sh` (restore before `gitops`), the purge; `HOW_TO_RUN.md` §3 and §5 updated | To do |
| 05.05 | End to end: automated walkthrough of every "Done When" check across a full `down.sh` and `up.sh` cycle; also runs checks 2 to 9 of 05.03 | To do |

Left to the step specs: the chart and plugin patch versions, the exact resources included in the
restore, and whether the verification commands become a script in the repository.
