# D-086 — Keeping the Database Volumes Until the Backup

Status: Accepted
Date: 2026-11-17
Phase: specs/05-lab-state-persistence

## Context

The cold backup ([D-079](079-backup-consistency.md)) needs the database volumes (PVCs, Kubernetes
requests for an EBS disk) to remain after `down.sh` deletes the `platform` Application. Two settings
delete three of the four before any backup:

- The source Postgres, Polaris catalog Postgres and Airflow Postgres manifests declare their
  namespaces (`postgres`, `polaris`, `airflow`), so Argo CD deletes them, with every PVC inside, along
  with the Application. `up.sh` already creates these namespaces.
- Their StatefulSets set `whenDeleted: Delete` (spec 02.02, so the teardown left no billed disks),
  which deletes the PVC with the StatefulSet.

The Airbyte database (`airbyte-db`) is not affected: its namespace comes from `CreateNamespace`, which
Argo CD does not delete, and its chart keeps the default `whenDeleted: Retain`.
Argo CD `selfHeal` (on in the parent and the database Applications) reverts manual changes, such as
scaling a database to 0, within about 5 seconds.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Remove the 3 Namespace objects (left to `up.sh`); `whenDeleted: Retain`; `down.sh` deletes `platform`, backs up, then deletes the 4 namespaces | Accepted practice: Argo CD sync options docs say namespaces "should not be pruned without confirmation" | Fewer lines; each namespace created in one place | Same | Meets D-079 as written; applying it to a running cluster deletes the 3 namespaces (none is running) |
| B. Keep the Namespace objects with `Delete=false`; `whenDeleted: Retain`; same `down.sh` order as A | Accepted practice: Argo CD app deletion docs give `Delete=false` to keep a resource | One annotation per namespace; namespaces created in two places | Same | Meets D-079 as written |
| C. `down.sh` turns off auto-sync on 4 Applications, scales the 4 databases to 0, backs up, then runs today's teardown | Accepted practice: Argo CD auto-sync docs describe turning auto-sync off for manual changes | Most `down.sh` steps; the parent must also ignore the change | Same | D-079's text ("deletes the `platform` Application") becomes inaccurate |

## Decision

- **Recommended:** A. All three are accepted practice, so principle 2 (simplicity) decides: fewer
  lines, and each namespace is created in one place (`up.sh`).
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Argo CD: sync options, Create Namespace](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)
- [Argo CD: app deletion](https://argo-cd.readthedocs.io/en/stable/user-guide/app_deletion/)
- [Argo CD: automated sync](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)
- [Argo CD: cluster bootstrapping](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Kubernetes: StatefulSets, PersistentVolumeClaim retention](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#persistentvolumeclaim-retention) (read through a summary)
- Airbyte chart 2.4.0, `templates/airbyte-db.yaml`: no retention policy
