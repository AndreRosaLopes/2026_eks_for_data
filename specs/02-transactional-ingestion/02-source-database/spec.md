# 02.02 — Source Database: Specification

Status: Implemented
Phase: [02 — Transactional Ingestion](../plan.md)

## Design

Postgres runs as a single-replica StatefulSet in the `postgres` namespace
([D-022](../../../docs/decisions/022-source-postgres.md)). The password lives in the local `.env` and
reaches the cluster through `kubectl`, with no Terraform
([D-031](../../../docs/decisions/031-source-postgres-password-from-env.md)); Argo CD syncs the rest
from Git.

1. **Password (`.env` and `kubectl`):**
   - `.env` (not versioned) holds `POSTGRES_PASSWORD` (32 hexadecimal characters, safe in connection
     strings) and, as a comment, the two commands below.
   - Before Argo CD syncs Postgres: `kubectl create namespace postgres` and
     `kubectl -n postgres create secret generic postgres-credentials --from-literal=password="$POSTGRES_PASSWORD"`.
   - `HOW_TO_RUN.md` section 2 gets the same two commands as its first step.
2. **`platform/aws/postgres/postgres.yaml` (Argo CD Application `postgres`, defined in
   `platform/aws/postgres.yaml`, [D-032](../../../docs/decisions/032-one-application-per-component.md)):**
   - Namespace `postgres`: also declared here, so Argo CD deletes it, with the Secret, at teardown.
   - ConfigMap `postgres-init`: `01-schemas.sql` with `CREATE SCHEMA tpch; CREATE SCHEMA oltp;`, run
     on the first start (empty volume).
   - StatefulSet `postgres`: image `postgres:18.6`; `POSTGRES_PASSWORD` from the Secret;
     `POSTGRES_DB=source`; args `-c wal_level=logical`; readiness probe `pg_isready`; volume 10 Gi at
     `/var/lib/postgresql` (EBS through the default `auto-ebs-sc`); requests 250m CPU and 1 Gi memory,
     no limits ([D-018](../../../docs/decisions/018-workload-resource-requests.md));
     `persistentVolumeClaimRetentionPolicy: whenDeleted: Delete`, so deleting the StatefulSet also
     deletes the EBS volume.
   - Service `postgres`: ClusterIP, port 5432. Airbyte and DuckDB reach it at
     `postgres.postgres.svc.cluster.local:5432`.

## Files

| File | Change |
|---|---|
| `.env` | Modify (local, not versioned): `POSTGRES_PASSWORD` and the `kubectl` commands as a comment |
| `HOW_TO_RUN.md` | Modify: section 2 starts with the password generation (`openssl rand -hex 16`) and the two `kubectl` commands |
| `platform/aws/postgres.yaml` | Create: Application `postgres` pointing to `platform/aws/postgres/` (D-032) |
| `platform/aws/postgres/postgres.yaml` | Create: Namespace, ConfigMap, StatefulSet and Service |
| `specs/02-transactional-ingestion/README.md` | Modify: Access (password command) and the 02.02 section |
| `specs/02-transactional-ingestion/plan.md` | Modify: step status |

## Verification Plan

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | Manifest is valid | `kubectl apply --dry-run=server -f platform/aws/postgres.yaml` | Every object `created (server dry run)` or `configured` | Pass: namespace configured; ConfigMap, Service, StatefulSet created (server dry run) |
| 2 | Automated | Secret exists before the sync | `kubectl -n postgres get secret postgres-credentials` | Secret with 1 data key | Pass: 1 data key, equal to `.env` |
| 3 | Automated | Argo CD synced Postgres | `kubectl -n argocd get application platform` | `Synced`, `Healthy` | Pass: `Synced`, `Healthy` |
| 4 | Automated | Pod ready and volume bound | `kubectl -n postgres get pod postgres-0` and `get pvc` | `1/1 Running`; PVC `Bound`, 10Gi | Pass: `1/1 Running`, 0 restarts; PVC `Bound`, 10Gi, `auto-ebs-sc` |
| 5 | Automated | Logical replication enabled | `kubectl -n postgres exec postgres-0 -- psql -U postgres -d source -tAc "SHOW wal_level"` | `logical` | Pass: `logical`; schemas `oltp` and `tpch` present |
| 6 | Automated | Reachable from the Airbyte namespace with the password | Temporary `postgres:18.6` pod in `airbyte` runs `psql` against the Service with the Secret's password | Prints `ok` | Pass: `ok` from a pod in `airbyte` |
| 7 | Manual | Password, schemas and replication, through the phase README | Read the password with `kubectl`; run `\dn` and `SHOW wal_level` through `kubectl exec` | Password printed; schemas `tpch` and `oltp`; `logical` | Pass: confirmed by the user |

## Teardown

Covered by phase 01 [Turn Off](../../../HOW_TO_RUN.md#51-turn-off): deleting the
`platform` Application cascades to the `postgres` Application, which prunes the StatefulSet (the retention policy deletes its PVC and EBS volume)
and the `postgres` namespace, with the Secret. Before the `cluster` destroy, `kubectl get pvc -A`
shows no `postgres` volume.
