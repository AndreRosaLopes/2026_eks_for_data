[How to Run](../../HOW_TO_RUN.md) › 05 — Lab state: [Run](HOW_TO_RUN.md) | **Verify**

# 05 — Lab State Between Environments: How to Verify

Labs continue where they stopped: `down.sh` saves the state of every database with Velero and
`up.sh` brings it back in the new cluster, while the S3 buckets survive the teardown. Every check of
this phase is automated and run by the agent; this page records them. The end-to-end verification
proves the phase [Done When](plan.md#done-when).

## Prerequisites and Access

- [How to Run, 2. Prerequisites](../../HOW_TO_RUN.md#2-prerequisites)
- [How to Run, 4. Access](../../HOW_TO_RUN.md#4-access): the services this phase uses

## Step Verification

### 05.01 — Roadmap

No manual check: this step only updates the roadmap in [README §3](../../README.md#3-phases)
([spec](01-roadmap/spec.md)).

### 05.02 — Persistent Data Root

No manual check: every check is automated and was run by the agent
([spec, Verification Plan](02-persistent-data-root/spec.md#verification-plan)). Expected results:
`./scripts/up.sh` creates the five `eks-for-data-*` buckets (bronze, silver, Airbyte, Airflow,
Velero), and after `./scripts/down.sh` the bronze and silver files are still there while no EKS
cluster, NAT Gateway or VPC is left.

### 05.03 — Snapshot Controller and Velero

No manual check: every check is automated and run by the agent
([spec, Verification Plan](03-snapshot-controller-velero/spec.md#verification-plan)); checks 2 to 9
run in step 05.05. Expected results: `./scripts/up.sh` installs the `snapshot-controller` add-on and
Velero, whose backup storage location is `Available`; a test volume is backed up with a CSI snapshot
and restored with its data; deleting the backup leaves no EBS snapshot; `./scripts/down.sh` removes
Velero with the cluster.

### 05.04 — Backup on Teardown, Restore on Bring-Up

No manual check: every check is automated and run by the agent
([spec, Verification Plan](04-backup-restore/spec.md#verification-plan)); checks 3 to 9 run in step
05.05. Expected results: [`./scripts/down.sh`](../../HOW_TO_RUN.md#35-turn-off) backs up the four
databases and keeps only the latest backup; afterwards only the buckets and four EBS snapshots are
left; [`./scripts/up.sh`](../../HOW_TO_RUN.md#31-bring-up) restores them before Argo CD, with the data
written before the teardown; [`./scripts/down.sh --purge`](../../HOW_TO_RUN.md#37-purge-full-reset)
leaves no bucket, backup or snapshot.

### 05.05 — End to End

No manual check: every check is automated and was run by the agent across a full
`up.sh` → `down.sh` → `up.sh` → `down.sh --purge` cycle
([spec, Verification Plan](05-end-to-end/spec.md#verification-plan)); it also ran the deferred
checks of 05.03 and 05.04. Expected results: the steps below.

## End-to-End Verification

Proves the phase [Done When](plan.md#done-when). Each step was run by the agent in step 05.05
([results](05-end-to-end/spec.md#verification-plan)); repeat it to verify by hand.

1. Bring the environment up with no backup: [How to Run, 3.1 Bring Up](../../HOW_TO_RUN.md#31-bring-up).
   - Expected result: `up.sh` prints `No backup in eks-for-data-velero-283429977024: starting with
     empty databases`; every application `Synced` and `Healthy`.
2. Create test data: TPC-H ([phase 02 How to Run, 1, 2 and 4](../02-transactional-ingestion/HOW_TO_RUN.md)),
   a CDC connection and one sync ([phase 02 Lab 03](../02-transactional-ingestion/lab03-cdc-ingestion.md)),
   a catalog, the engines' principal and a `silver` table from DuckDB
   ([phase 03 How to Run, 4, 5 and 7](../03-processing-spark-iceberg/HOW_TO_RUN.md)), one run of
   `smoke_test` ([phase 04 How to Run](../04-orchestration-airflow/HOW_TO_RUN.md)), and a marker row
   in each of the four databases ([How to Run, 4. Access](../../HOW_TO_RUN.md#4-access)). Write down
   the TPC-H row counts, the `airbyte_slot` position and the silver row count.
3. Tear down: [How to Run, 3.5 Turn Off](../../HOW_TO_RUN.md#35-turn-off) (`./scripts/down.sh`).
   - Expected result: the backup ends `Completed` with five volume snapshots; afterwards
     [3.6](../../HOW_TO_RUN.md#36-check-nothing-is-left) lists nothing, and only the five
     `eks-for-data-*` buckets, one backup and five tagged EBS snapshots are left.
4. Bring the environment up again: [How to Run, 3.1 Bring Up](../../HOW_TO_RUN.md#31-bring-up),
   including 3.2 step 7 (Polaris engine credentials after a restore).
   - Expected result: the restore ends `Completed` before Argo CD creates `platform`; every
     application `Synced` and `Healthy`.
5. Read the restored state.
   - Expected result: the four markers; the same TPC-H row counts and the slot `airbyte_slot`; the
     same Airbyte connection, whose next sync, after one row is inserted, writes only that row to
     bronze; DuckDB reads the same `silver` row count through Polaris; Airflow lists the
     `smoke_test` run and its task log opens.
6. Reset everything: [How to Run, 3.7 Purge](../../HOW_TO_RUN.md#37-purge-full-reset).
   - Expected result: no `eks-for-data-*` bucket, EBS snapshot, volume, cluster, NAT Gateway or VPC.
7. Search the repository for each `.env` value (`git grep`).
   - Expected result: no password, token or key; only the non-secret profile, region, account,
     repository and Git user values.

## Teardown

The whole environment: [How to Run, 3.5 Turn Off](../../HOW_TO_RUN.md#35-turn-off). Each step's own
teardown is in its spec:

- [05.01 — Roadmap](01-roadmap/spec.md#teardown)
- [05.02 — Persistent Data Root](02-persistent-data-root/spec.md#teardown)
- [05.03 — Snapshot Controller and Velero](03-snapshot-controller-velero/spec.md#teardown)
- [05.04 — Backup on Teardown, Restore on Bring-Up](04-backup-restore/spec.md#teardown)
- [05.05 — End to End](05-end-to-end/spec.md#teardown)
