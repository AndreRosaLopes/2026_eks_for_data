# 05.05 — End to End: Specification

Status: Approved
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
| Test data: markers | Table `lab_marker`, one row, in each of the four databases | User's decision in this spec |
| Test data: source Postgres | Scripts `01`, `02` and `04` of `pipelines/tpch`, at scale factor 0.01 | [D-024](../../../docs/decisions/024-tpch-dataset-and-scale.md) |
| Test data: Airbyte | Postgres source, S3 destination and one CDC connection with only `region`, created through the Airbyte API | User's decision in this spec |
| Test data: Polaris and silver | Catalog and engine principal, as in phase 03 `HOW_TO_RUN.md` §4 and §5 | [D-060](../../../docs/decisions/060-polaris-catalog-creation.md), [D-062](../../../docs/decisions/062-polaris-engine-credentials.md) |
| Test data: Polaris and silver | `silver.orders` with 3 rows, created from DuckDB | User's decision in this spec |
| Test data: Polaris and silver | Fallback if DuckDB cannot write to the silver bucket: the dedup job over 3 rows that DuckDB writes to bronze | User's decision in this spec |
| Test data: Airflow | One run of the `smoke_test` DAG | User's decision in this spec |
| Purge run | The agent asks for confirmation before `down.sh --purge` (irreversible) | `AGENTS.md` §1.4 |

## Files

| File | Change |
|---|---|
| `specs/05-lab-state-persistence/05-end-to-end/spec.md` | Create: this spec, with the check results |
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
| 1 | Automated | First bring-up, no backup (05.04 #3) | `up.sh` | "No backup" message; every application `Synced` and `Healthy` | Pending |
| 2 | Automated | Add-on installed (05.03 #2) | `aws eks describe-addon` for `snapshot-controller` | `ACTIVE`, `v8.7.0-eksbuild.4` | Pending |
| 3 | Automated | Velero role limited to S3 (05.03 #3) | Read the policies of `eks-for-data-velero` | Only `s3:` actions; only the Velero bucket | Pending |
| 4 | Automated | Velero reaches its bucket (05.03 #4) | `kubectl -n velero get backupstoragelocation` | `Available` | Pending |
| 5 | Automated | Snapshot class as specified (05.03 #5) | `kubectl get volumesnapshotclass -o yaml` | Driver, `Retain` and label as in 05.03 Design | Pending |
| 6 | Automated | Test data created | Test data rows of Design | Each item created; Airbyte sync `Succeeded`; DuckDB reads 3 rows of `silver.orders` | Pending |
| 7 | Automated | State recorded; extra backup made | Record TPC-H counts, CDC slot, Airbyte connection, `silver.orders` count, DAG run; `velero backup create lab-old` | Every value recorded; `lab-old` `Completed` | Pending |
| 8 | Automated | Teardown backs up first, with no pod attached (05.04 #4, 05.03 #6) | `down.sh`; `velero backup describe` of the new backup before Velero goes | `Completed`, four volume snapshots | Pending |
| 9 | Automated | Only the latest backup kept; its deletion removes the snapshots (05.04 #8, 05.03 #8) | List the backups in the Velero bucket and the tagged EBS snapshots | One backup, not `lab-old`; four snapshots | Pending |
| 10 | Automated | After teardown, only data left (05.04 #5, 05.03 #9; Done When 6) | `down.sh` final lists; `terraform state list` on `backup`; tagged EBS volumes; buckets | Empty state and lists; no volume; five buckets | Pending |
| 11 | Automated | Restore before Argo CD (05.04 #6) | `up.sh`; restore completion time vs. creation time of the `platform` Application | Restore `Completed` earlier | Pending |
| 12 | Automated | Markers back (05.04 #7, 05.03 #7; Done When 1) | Read `lab_marker` in the four databases | Four markers; applications `Synced` and `Healthy` | Pending |
| 13 | Automated | Source intact (Done When 2) | Row count per TPC-H table; `pg_replication_slots` | Same counts as check 7; slot exists | Pending |
| 14 | Automated | Airbyte resumes CDC (Done When 3) | Read the connection through the API; insert 1 row in `region`; sync; read the job's record count | Same connection; 1 record read | Pending |
| 15 | Automated | Silver readable (Done When 4) | DuckDB `count(*)` on `silver.orders` through Polaris | 3 rows | Pending |
| 16 | Automated | Airflow history kept (Done When 5) | List the `smoke_test` DAG runs; open its task log | Run from check 7 listed; log opens | Pending |
| 17 | Automated | Purge leaves nothing (05.04 #9; Done When 6) | `down.sh --purge`; list `eks-for-data-*` buckets, tagged snapshots and volumes | Every list empty | Pending |
| 18 | Automated | No secrets in the repository (Done When 7) | `git grep` for each `.env` value | Nothing found | Pending |

## Teardown

Check 17 runs the purge: no bucket, backup, snapshot or cluster is left.
