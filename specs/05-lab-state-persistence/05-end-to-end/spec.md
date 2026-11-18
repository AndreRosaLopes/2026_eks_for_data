# 05.05 — End to End: Specification

Status: Implemented
Phase: [05 — Lab State Between Environments](../plan.md)

## Design

| Component | Configuration | ADR |
|---|---|---|
| End-to-end checks | Run by the agent, no script in the repository | [D-089](../../../docs/decisions/089-end-to-end-check-method.md) |
| End-to-end checks | Listed as steps in the phase `README.md`, "End-to-End Verification" | [D-089](../../../docs/decisions/089-end-to-end-check-method.md) |
| Cycle order | `up.sh` → test data and an extra backup → `down.sh` → `up.sh` → `down.sh --purge` | User's decision in this spec |
| Cycle order | Ends with the purge: nothing is left | User's decision in this spec |
| Retention test | An extra Velero backup `lab-old`, created by hand before the first `down.sh`; `down.sh` must delete it | User's decision in this spec |
| 05.03 test volume | Not created: checks 6 to 8 of 05.03 are covered by the database volumes | User's decision in this spec |
| Backup content | Five volumes: the four databases plus `logs-airflow-triggerer-0`, the Airflow triggerer's log volume in the `airflow` namespace; kept as is | User's decision during check 7 |
| Test data: markers | Table `lab_marker`, one row, in each of the four databases | User's decision in this spec |
| Test data: source Postgres | Scripts `01`, `02` and `04` of `pipelines/tpch`, at scale factor 0.01 | [D-024](../../../docs/decisions/024-tpch-dataset-and-scale.md) |
| Test data: Airbyte | Postgres source, S3 destination and one CDC connection with only `region`, created through the Airbyte API | User's decision in this spec |
| Test data: Polaris and silver | Catalog and engine principal, as in phase 03 `HOW_TO_RUN.md` §4 and §5 | [D-060](../../../docs/decisions/060-polaris-catalog-creation.md), [D-062](../../../docs/decisions/062-polaris-engine-credentials.md) |
| Test data: Polaris and silver | `silver.orders` with 3 rows, created from DuckDB | User's decision in this spec |
| Test data: Polaris and silver | Fallback if DuckDB cannot write to the silver bucket: the dedup job over 3 rows that DuckDB writes to bronze | User's decision in this spec |
| Test data: Airflow | One run of the `smoke_test` DAG | User's decision in this spec |
| `down.sh` before the backup | Re-creates the `auto-ebs-sc` StorageClass, which the `platform` cascade deletes; Velero's CSI plugin reads it to snapshot each volume (without it the backup ends `PartiallyFailed`) | User's decision during check 8 |
| `up.sh` restore | Also includes `volumesnapshots` and `volumesnapshotcontents`: a PVC-only restore leaves each claim `Pending`, pointing to a VolumeSnapshot Velero skipped (answers the 05.04 open point) | User's decision during check 12 |
| Purge run | The agent asks for confirmation before `down.sh --purge` (irreversible) | `AGENTS.md` §1.4 |

## Files

| File | Change |
|---|---|
| `specs/05-lab-state-persistence/05-end-to-end/spec.md` | Create: this spec, with the check results |
| `scripts/up.sh` | Modify: the backup lookup no longer stops the script when the Velero bucket has no `backups/` prefix yet (`aws s3 ls` exits 1), approved during check 1; the restore also includes the VolumeSnapshots and their contents, approved during check 12 |
| `scripts/down.sh` | Modify: `kubectl apply -f platform/aws/storageclass.yaml` after the `platform` deletion, before the backup; approved by the user during check 8 |
| `HOW_TO_RUN.md` | Modify: §5.1 manual teardown gets the same StorageClass line; §3.2 step 2 restore gets the same resources as `up.sh`; §3.2 step 7 for the Polaris engine credentials; §5 names the five backed-up volumes; §1 phase 05 `Done` |
| `specs/03-processing-spark-iceberg/HOW_TO_RUN.md` | Modify: §5 says when to run it after a restore (step 4 only) and with no backup (all, removing the old `.env` lines first); added at the user's request when closing the phase |
| `specs/05-lab-state-persistence/03-snapshot-controller-velero/spec.md` | Modify: results of checks 2 to 9; checks 6 to 8 point to the 05.05 checks that cover them |
| `specs/05-lab-state-persistence/04-backup-restore/spec.md` | Modify: results of checks 3 to 9 |
| `specs/05-lab-state-persistence/README.md` | Modify: the 05.05 section and "End-to-End Verification" |
| `specs/05-lab-state-persistence/plan.md` | Modify: the step 05.05 row also names checks 3 to 9 of 05.04, matching Divergences |

## Verification Plan

No manual check: by the user's decision, every test of this phase is automated and run by the agent
(plan, Scope). This step skips the "at least one Manual check" rule.

Order: checks 1 to 7 after the first `up.sh`; 8 to 10 during and after the first `down.sh`; 11 to
16 after the second `up.sh`; 17 and 18 with `down.sh --purge`. A failed check stops the sequence
before the next script.

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | First bring-up, no backup (05.04 #3) | `up.sh` | "No backup" message; every application `Synced` and `Healthy` | Fail, then Pass after a fix: the first run exited 1 with no message (`aws s3 ls` of the empty `backups/` prefix exits 1 under `set -e`); after the approved `up.sh` fix: `No backup in eks-for-data-velero-283429977024: starting with empty databases`, realm bootstrapped, all ten applications `Synced` and `Healthy` |
| 2 | Automated | Add-on installed (05.03 #2) | `aws eks describe-addon` for `snapshot-controller` | `ACTIVE`, `v8.7.0-eksbuild.4` | Pass: `ACTIVE`, `v8.7.0-eksbuild.4` |
| 3 | Automated | Velero role limited to S3 (05.03 #3) | Read the policies of `eks-for-data-velero` | Only `s3:` actions; only the Velero bucket | Pass: one attached policy `eks-for-data-velero`, no inline policy; `s3:ListBucket` on `eks-for-data-velero-283429977024` and `s3:GetObject`, `PutObject`, `DeleteObject`, `PutObjectTagging`, `AbortMultipartUpload`, `ListMultipartUploadParts` on its objects only |
| 4 | Automated | Velero reaches its bucket (05.03 #4) | `kubectl -n velero get backupstoragelocation` | `Available` | Pass: `default` `Available` |
| 5 | Automated | Snapshot class as specified (05.03 #5) | `kubectl get volumesnapshotclass -o yaml` | Driver, `Retain` and label as in 05.03 Design | Pass: `ebs-csi`, driver `ebs.csi.eks.amazonaws.com`, `deletionPolicy: Retain`, label `velero.io/csi-volumesnapshot-class: "true"` |
| 6 | Automated | Test data created | Test data rows of Design | Each item created; Airbyte sync `Succeeded`; DuckDB reads 3 rows of `silver.orders` | Pass: TPC-H SF 0.01 (`tpch` orders 15,000, lineitem 60,175; `oltp` orders 13,654), publication and `airbyte_slot`; source, destination and connection `54f57308-7b7d-48e2-bbde-9f695a3c51cf` created through the API, sync 1 `succeeded` (5 rows); catalog `lab`, principal `engines`; DuckDB wrote `silver.orders` directly (no fallback), 3 rows; `smoke_test` run `success`, log opens; `lab_marker` in the four databases |
| 7 | Automated | State recorded; extra backup made | Record TPC-H counts, CDC slot, Airbyte connection, `silver.orders` count, DAG run; `velero backup create lab-old` | Every value recorded; `lab-old` `Completed` | Pass: 16 TPC-H/`oltp` counts, slot `airbyte_slot` at `0/38CD5B8`, connection, `silver.orders` 3, run `manual__2026-11-17T15:55:12.636397+00:00` recorded; `lab-old` `Completed` with 5 snapshots (the triggerer logs volume was not expected; kept by the user's decision, Design) |
| 8 | Automated | Teardown backs up first, with no pod attached (05.04 #4, 05.03 #6) | `down.sh`; `velero backup describe` of the new backup before Velero goes | `Completed`, five volume snapshots: the four databases plus the Airflow triggerer logs volume `logs-airflow-triggerer-0` | Fail, then Pass after a fix: the first backup `lab-20261117160513` ended `PartiallyFailed` (`storageclasses.storage.k8s.io "auto-ebs-sc" not found`) and `down.sh` stopped before deleting anything; after the approved `down.sh` fix: `lab-20261117165746` `Completed`, 5 CSI snapshot operations `Completed`, taken after the `platform` deletion (no pod attached) |
| 9 | Automated | Only the latest backup kept; its deletion removes the snapshots (05.04 #8, 05.03 #8) | List the backups in the Velero bucket and the tagged EBS snapshots | One backup, not `lab-old`; five snapshots | Pass: bucket holds only `backups/lab-20261117165746/`; 5 tagged snapshots (1, 1, 1, 10 and 100 GiB); the 5 snapshots of `lab-old` return `InvalidSnapshot.NotFound` |
| 10 | Automated | After teardown, only data left (05.04 #5, 05.03 #9; Done When 6) | `down.sh` final lists; `terraform state list` on `backup`; tagged EBS volumes; buckets | Empty state and lists; no volume; five buckets | Pass: `down.sh` exit 0, final lists empty; `backup`, `cluster`, `gitops` states empty; no tagged volume; five `eks-for-data-*` buckets |
| 11 | Automated | Restore before Argo CD (05.04 #6) | `up.sh`; restore completion time vs. creation time of the `platform` Application | Restore `Completed` earlier | Fail, then Pass after a fix: the first restore `Completed` but restored only the claims and their VolumeSnapshotContents, not the VolumeSnapshots (`Skipping restore of resource because the restore spec excludes it`), so every claim stayed `Pending` and `up.sh` timed out on `polaris-postgres`; after the approved `up.sh` fix and a recovery on the same cluster (services, claims and restored contents deleted, `gitops` destroyed, `up.sh` re-run): restore `lab-20261117165746-20261117172549` completed 20:25:55Z, `platform` created 20:27:46Z |
| 12 | Automated | Markers back (05.04 #7, 05.03 #7; Done When 1) | Read `lab_marker` in the four databases | Four markers; applications `Synced` and `Healthy` | Pass: the four `lab_marker` rows read with their original `written_at` (15:47Z); all applications `Healthy` after the crashed pods were moved off a CPU-starved node and a failed node was deleted (not caused by the restore) |
| 13 | Automated | Source intact (Done When 2) | Row count per TPC-H table; `pg_replication_slots` | Same counts as check 7; slot exists | Pass: the 16 table counts identical to check 7; `airbyte_slot` exists at `0/38CD5B8` |
| 14 | Automated | Airbyte resumes CDC (Done When 3) | Read the connection through the API; insert 1 row in `region`; sync; read the job's record count | Same connection; 1 record read | Pass: connection `54f57308-7b7d-48e2-bbde-9f695a3c51cf` read through the API; row `100:LAB0505` inserted; sync 2 resumed from `Confirmed flush LSN: LSN{0/38CD5B8}, source state LSN: LSN{0/38CD5B8}` (no resync) and wrote one bronze file with exactly that 1 record (the job's API record count was lost when a node failed; read from the file) |
| 15 | Automated | Silver readable (Done When 4) | DuckDB `count(*)` on `silver.orders` through Polaris | 3 rows | Pass: 3 rows, with `polaris-credentials` re-created from `.env` (phase 03 How to Run §5 step 4); the realm bootstrap reported `already bootstrapped` |
| 16 | Automated | Airflow history kept (Done When 5) | List the `smoke_test` DAG runs; open its task log | Run from check 7 listed; log opens | Pass: run `manual__2026-11-17T15:55:12.636397+00:00` `success` listed; its task log opens (`smoke test: hello from a KubernetesExecutor task pod`) |
| 17 | Automated | Purge leaves nothing (05.04 #9; Done When 6) | `down.sh --purge`; list `eks-for-data-*` buckets, tagged snapshots and volumes | Every list empty | Pass: `down.sh --purge` exit 0 (backup `lab-20261117165746` deleted, then `gitops` 2, `backup` 1, `cluster` 76 and `data` 15 resources destroyed); no `eks-for-data-*` bucket, tagged snapshot, volume, instance, EKS cluster, NAT Gateway, Elastic IP or VPC; all four Terraform states empty |
| 18 | Automated | No secrets in the repository (Done When 7) | `git grep` for each `.env` value | Nothing found | Pass: no `.env` password, token or key found, committed or not; only the non-secret `AWS_PROFILE`, `AWS_REGION`, `ACCOUNT_ID`, `REPO_NAME` and `GIT_USER` values match |

## Teardown

Check 17 runs the purge: no bucket, backup, snapshot or cluster is left.
