# 02.03 — DuckDB Service: Specification

Status: Implemented
Phase: [02 — Transactional Ingestion](../plan.md)

## Design

DuckDB 2.0 runs as one in-memory pod in the `duckdb` namespace, as its own Argo CD Application
([D-023](../../../docs/decisions/023-duckdb-service.md),
[D-032](../../../docs/decisions/032-one-application-per-component.md),
[D-033](../../../docs/decisions/033-duckdb-service-configuration.md)).

1. **IRSA (`infra/aws/cluster`, [D-008](../../../docs/decisions/008-pod-aws-identity.md)):** module
   `duckdb_irsa`, like `airbyte_irsa`, for the ServiceAccount `duckdb:duckdb`, read-only on the
   bronze bucket (`s3:GetObject`, `s3:ListBucket`, `s3:GetBucketLocation`); output `duckdb_role_arn`.
2. **Secrets (`.env` + `kubectl`, D-033 1A):** `.env` gets a generated `QUACK_TOKEN` and the commands
   as a comment; `HOW_TO_RUN.md` §2 step 1 adds `kubectl create namespace duckdb` and the Secret
   `duckdb-credentials` with the keys `quack-token` and `postgres-password`.
3. **`platform/aws/duckdb.yaml`:** Application `duckdb` pointing to `platform/aws/duckdb/`.
4. **`platform/aws/duckdb/duckdb.yaml`:**
   - Namespace `duckdb`.
   - ServiceAccount `duckdb` annotated with the IRSA role ARN.
   - ConfigMap `duckdb-init` with `init.sql`, run at startup:
     - `SET memory_limit = '1536MB'`;
     - attaches Postgres as `source` through the libpq variables (`PGHOST`, `PGUSER`, `PGDATABASE`,
       `PGPASSWORD`), so the password never appears in SQL;
     - creates an S3 secret with `PROVIDER credential_chain`, region `us-east-1` (IRSA web identity);
     - `SELECT listen_url FROM quack_serve('quack:0.0.0.0:9494', allow_other_hostname = true,
       disable_ssl = true, token = getenv('QUACK_TOKEN'))`; only the URL is selected because
       `CALL quack_serve(...)` prints the token to the pod logs;
     - `start_ui_server()` (UI on port 4213 inside the pod, D-033 4B).
   - Deployment `duckdb`: 1 replica, image `duckdb/duckdb:2.0.0`, args `-init /config/init.sql`,
     environment from the Secret, `HOME` on an `emptyDir` (extensions `postgres`, `httpfs`, `quack`,
     `ui` installed at startup), `stdin: true` and `tty: true` so the CLI stays open after
     `init.sql`, requests 500m CPU and 2 Gi memory, no limits
     ([D-018](../../../docs/decisions/018-workload-resource-requests.md)).
   - Service `duckdb`: ClusterIP, port 9494 (Quack). The UI is reached by port-forward to the pod.

**Verified only during implementation** (not settled by the documentation; a failure is reported
as a divergence): the CLI stays open with `stdin`/`tty` (or the `-serve` flag does it better);
`getenv` works in `quack_serve`; the IRSA credential chain works; Quack clients see the server's
attached `source` catalog.

## Files

| File | Change |
|---|---|
| `infra/aws/cluster/storage.tf` | Modify: `duckdb_irsa` module (read-only on bronze) |
| `infra/aws/cluster/outputs.tf` | Modify: `duckdb_role_arn` |
| `.env` (local, not versioned) | Modify: `QUACK_TOKEN` and the commands as a comment |
| `HOW_TO_RUN.md` | Modify: §2 step 1 adds the `duckdb` namespace and Secret; the §2 check lists `duckdb` |
| `platform/aws/duckdb.yaml` | Create: Application `duckdb` |
| `platform/aws/duckdb/duckdb.yaml` | Create: Namespace, ServiceAccount, ConfigMap, Deployment, Service |
| `specs/02-transactional-ingestion/README.md` | Modify: Access (Quack token; UI in the pod, main; UI on your computer, alternative) and the 02.03 section |
| `specs/02-transactional-ingestion/plan.md` | Modify: step status |

## Verification Plan

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | IRSA plan | `terraform -chdir=infra/aws/cluster plan` | Only the DuckDB role, policy and attachment added; 0 changed, 0 destroyed | Pass: 3 to add (role, policy, attachment), 0 changed, 0 destroyed; applied |
| 2 | Automated | Manifest valid | `kubectl apply --dry-run=server -f platform/aws/duckdb/duckdb.yaml` | Every object created or configured | Pass: namespace configured; ServiceAccount, ConfigMap, Service, Deployment created (server dry run) |
| 3 | Automated | Argo CD | `kubectl -n argocd get application duckdb` | `Synced`, `Healthy` | Pass: `Synced`, `Healthy` |
| 4 | Automated | Server stays up | `kubectl -n duckdb get pod` after 2 minutes; logs | `1/1 Running`, 0 restarts; no errors from `init.sql` | Pass: `1/1 Running`, 0 restarts after 2 min; `init.sql` ran with no errors; CLI kept open by `stdin`/`tty` |
| 5 | Automated | Quack from a client pod | Temporary `duckdb/duckdb:2.0.0` pod attaches `quack:duckdb.duckdb.svc.cluster.local:9494` with the token and lists the `source` schemas | `oltp` and `tpch` | Pass: client sees `oltp` and `tpch` (with `CREATE SECRET (TYPE quack, TOKEN getenv(...))` and `DISABLE_SSL true`) |
| 6 | Automated | Wrong token rejected | Same, with a wrong token | Authentication error | Pass: `Invalid Input Error: Authentication failed` |
| 7 | Automated | S3 read through IRSA | Inside the DuckDB pod (`kubectl exec`; a `glob` sent through Quack runs on the client, which has no AWS role): `SELECT count(*) FROM glob('s3://<bronze>/**')` | A number (0 or more), no `AccessDenied` | Pass: `0` files, no error (bronze empty in this environment); the Airbyte bucket returns `AccessDenied` for role `eks-for-data-duckdb`, so IRSA is in use |
| 8 | Manual | UI in the pod | `kubectl -n duckdb port-forward deploy/duckdb 4213:4213`, open `http://localhost:4213`, run `FROM duckdb_databases()` and `SELECT schema_name FROM source.information_schema.schemata` | `source` listed; `oltp` and `tpch` | Pass: confirmed by the user (UI on local port 4213) |

## Teardown

Covered by phase 01 [Turn Off](../../../HOW_TO_RUN.md#51-turn-off): deleting the
`platform` Application cascades to `duckdb`, which prunes the Namespace (with the Secret); there is
no volume. `terraform -chdir=infra/aws/cluster destroy` removes the IRSA role.
