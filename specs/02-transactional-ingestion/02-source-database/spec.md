# 02.02 — Source Database: Specification

Status: Approved
Phase: [02 — Transactional Ingestion](../plan.md)

## Design

Postgres runs as a single-replica StatefulSet in the `postgres` namespace
([D-022](../../../docs/decisions/022-source-postgres.md)). Terraform creates the namespace and the
password ([D-030](../../../docs/decisions/030-source-postgres-password.md)); Argo CD syncs the rest
from Git.

1. **`infra/aws/gitops` (Terraform):**
   - `kubernetes` (~> 3.4) and `random` (~> 3.9) providers; `kubernetes` authenticates with the same
     `aws eks get-token` exec block as `helm`.
   - `kubernetes_namespace_v1.postgres`: namespace `postgres`.
   - `random_password.postgres`: 32 characters, no special characters (safe in connection strings).
   - `kubernetes_secret_v1.postgres`: Secret `postgres-credentials` with key `password`.
   - `helm_release.argocd_apps` gets `depends_on` the Secret, so Argo CD never syncs the StatefulSet
     before its Secret exists.
2. **`platform/aws/postgres.yaml` (Argo CD):**
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
| `infra/aws/gitops/providers.tf` | Modify: `kubernetes` and `random` providers |
| `infra/aws/gitops/postgres.tf` | Create: namespace, password and Secret |
| `infra/aws/gitops/argocd.tf` | Modify: `depends_on` the Secret in `argocd_apps` |
| `infra/aws/gitops/.terraform.lock.hcl` | Modify: provider locks |
| `platform/aws/postgres.yaml` | Create: ConfigMap, StatefulSet and Service |
| `specs/02-transactional-ingestion/README.md` | Modify: Access (password command) and the 02.02 section |
| `specs/02-transactional-ingestion/plan.md` | Modify: step status |

## Verification Plan

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | Terraform is valid | `terraform -chdir=infra/aws/gitops validate` and `fmt -check` | Success | Pending |
| 2 | Automated | Plan only adds the new resources | `terraform -chdir=infra/aws/gitops plan` | 3 to add (namespace, password, Secret); `argocd_apps` unchanged or updated in place | Pending |
| 3 | Automated | Argo CD synced Postgres | `kubectl -n argocd get application platform` | `Synced`, `Healthy` | Pending |
| 4 | Automated | Pod ready and volume bound | `kubectl -n postgres get pod postgres-0` and `get pvc` | `1/1 Running`; PVC `Bound`, 10Gi | Pending |
| 5 | Automated | Logical replication enabled | `kubectl -n postgres exec postgres-0 -- psql -U postgres -d source -tAc "SHOW wal_level"` | `logical` | Pending |
| 6 | Automated | Reachable from the Airbyte namespace with the password | Temporary `postgres:18.6` pod in `airbyte` runs `psql` against the Service with the Secret's password | Prints `ok` | Pending |
| 7 | Manual | Password, schemas and replication, through the phase README | Read the password with `kubectl`; run `\dn` and `SHOW wal_level` through `kubectl exec` | Password printed; schemas `tpch` and `oltp`; `logical` | Pending |

## Teardown

Covered by phase 01 [Turn Off](../../01-ingestion-airbyte-s3/README.md#turn-off): deleting the
`platform` Application prunes the StatefulSet, and the retention policy deletes its PVC and EBS
volume; `terraform -chdir=infra/aws/gitops destroy` then removes the Secret, the password and the
namespace. Before the `cluster` destroy, `kubectl get pvc -A` shows no `postgres` volume.
