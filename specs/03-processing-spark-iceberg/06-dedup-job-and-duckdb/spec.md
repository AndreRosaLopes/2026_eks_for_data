# 03.06 — Dedup Job and DuckDB Read-Back: Specification

Status: Approved
Phase: [03 — Processing: Spark and Iceberg](../plan.md)

## Design

| Component | Configuration | ADR |
|---|---|---|
| Engine credentials | One Polaris principal for Spark and DuckDB, created in the lab with the Polaris CLI | [D-062](../../../docs/decisions/062-polaris-engine-credentials.md) |
| Credentials in the cluster | Client ID and secret in `.env`, sent with `kubectl` as Secret `polaris-credentials` in namespaces `spark` and `duckdb` | [D-031](../../../docs/decisions/031-source-postgres-password-from-env.md) |
| Dedup job | `SparkApplication` `dedup-orders` in `pipelines/spark/`, started with `kubectl apply` | [D-057](../../../docs/decisions/057-spark-job-run-start.md) |
| Job script | `pipelines/spark/dedup_orders.py`, delivered in ConfigMap `spark-jobs` | [D-048](../../../docs/decisions/048-spark-job-code-delivery.md) |
| Job logic | Dedup rule and write method chosen in the lab | — |
| Catalog, namespace and table | Job arguments, chosen in the lab | [D-060](../../../docs/decisions/060-polaris-catalog-creation.md) |
| Spark catalog connection | Iceberg REST at `http://polaris.polaris.svc.cluster.local:8181/api/catalog` | [D-044](../../../docs/decisions/044-iceberg-rest-catalog-server.md) |
| Spark silver access | Credentials vended by Polaris (`X-Iceberg-Access-Delegation: vended-credentials`) | [D-049](../../../docs/decisions/049-silver-storage-credentials.md) |
| Spark bronze access | S3A with IRSA, as in 03.04 | [D-058](../../../docs/decisions/058-spark-s3a-credentials.md) |
| Job image and resources | Same as 03.04 | [D-054](../../../docs/decisions/054-spark-image-tag.md) |
| DuckDB credentials | Deployment `duckdb` reads `polaris-credentials` as environment variables | [D-033](../../../docs/decisions/033-duckdb-service-configuration.md) |
| DuckDB read-back | DuckDB UI: `ATTACH` of the lab catalog, `ACCESS_DELEGATION_MODE 'vended_credentials'` | [D-049](../../../docs/decisions/049-silver-storage-credentials.md) |

## Files

| File | Change |
|---|---|
| `pipelines/spark/dedup_orders.py` | Create: dedup job, the starting point for the lab |
| `pipelines/spark/dedup-orders.yaml` | Create: `SparkApplication` with the Polaris connection and job arguments |
| `pipelines/spark/kustomization.yaml` | Modify: add the new script to ConfigMap `spark-jobs` |
| `platform/aws/duckdb/duckdb.yaml` | Modify: Polaris credentials as environment variables |
| `specs/03-processing-spark-iceberg/HOW_TO_RUN.md` §5 | Secret `polaris-credentials` in `spark` and `duckdb` (moved from home §3.2: the principal is created in the lab, after Polaris is up, so its Secret cannot exist at bring-up) |
| `specs/03-processing-spark-iceberg/HOW_TO_RUN.md` | Modify: principal setup, job run, DuckDB attach |
| `specs/03-processing-spark-iceberg/README.md` | Modify: 03.06 section and the end-to-end verification |
| `specs/03-processing-spark-iceberg/plan.md` | Modify: step and phase status |

## Verification Plan

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Manual | Principal ready | Polaris CLI: `principals list`; then `kubectl get secret polaris-credentials` in `spark` and `duckdb` | Principal listed; both Secrets exist | Pass (run by the agent with example names): principal `engines`, principal role `engine_role`, catalog role `verify_contributor` with `CATALOG_MANAGE_CONTENT` on catalog `verify`; Secret `polaris-credentials` in `spark` and `duckdb` |
| 2 | Manual | Job reads bronze and writes the table (Done When 1) | `kubectl apply -f pipelines/spark/dedup-orders.yaml`, then `kubectl -n spark get sparkapplication` | State `COMPLETED`; driver log shows the bronze rows read | Pass (catalog `verify`, namespace `silver`, table `orders`): `COMPLETED` in 135 s; `silver silver.orders: rows=1366377 distinct_orderkey=1366377`; the `NoSuchTableException` 404 in the log is `createOrReplace` checking for the table on the first run |
| 3 | Automated | Table in the catalog (Done When 2) | Iceberg REST API: list the lab namespace's tables | The table is listed | Pass: with the `engines` credentials, `GET .../verify/namespaces/silver/tables` lists `silver.orders` |
| 4 | Automated | One row per `orderkey`, latest version (Done When 2) | DuckDB: table row count vs. distinct `orderkey`; rows whose `updated_at` differs from bronze's latest per `orderkey` | Counts equal; 0 rows differ | Pass: 1,366,377 rows = 1,366,377 distinct `orderkey` = 1,366,377 in bronze; 0 rows whose `updated_at` differs from bronze's latest |
| 5 | Manual | DuckDB reads through the catalog (Done When 3) | DuckDB UI: `ATTACH` the lab catalog, count rows; count distinct `orderkey` in bronze | Both counts equal | Pass (run by the agent with the DuckDB CLI in the pod, same SQL as the UI): `ATTACH` with `getenv()` credentials and vended credentials; `silver_rows` 1,366,377 = `bronze_orderkeys` 1,366,377 |
| 6 | Automated | No secrets in the repository (Done When 5) | `git grep` for every `.env` value | No match | Pass (2026-11-09, after the principal was created): no match for the 7 secret values (`PASSWORD`, `SECRET`, `TOKEN`); the non-secret values (profile, region, account ID per D-020, repository, Git user) are excluded |
| 7 | Manual | Teardown removes every resource with cost (Done When 4) | [Turn Off](../../../HOW_TO_RUN.md#51-turn-off), then the AWS console: EKS, EC2 (instances, volumes, NAT gateways, load balancers), S3 | No cluster, instance, volume, NAT gateway, load balancer or bucket of the project remains | Pending |

## Teardown

- The finished job holds no CPU or memory; delete it with
  `kubectl -n spark delete sparkapplication dedup-orders` before a re-run.
- The silver table files go with the bucket (`force_destroy`), and the catalog entries with the
  catalog Postgres, at [Turn Off](../../../HOW_TO_RUN.md#51-turn-off).
