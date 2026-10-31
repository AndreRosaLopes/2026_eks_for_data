# D-033 — DuckDB Service Configuration

Status: Accepted
Date: 2026-10-31
Phase: specs/02-transactional-ingestion

## Context

[D-023](023-duckdb-service.md) chose Quack (beta) for DuckDB as a service. Running it in the
cluster raises four choices: how the Quack token and the Postgres password reach the pod, where
DuckDB keeps its data, which transport Quack uses, and how the user runs queries in a UI. Quack's
default port is 9494; a non-local server needs `allow_other_hostname = true` and serves HTTPS with a
self-signed certificate unless `disable_ssl = true`. The DuckDB UI extension serves a browser editor
on port 4213 of the DuckDB process that starts it.

## Alternatives

### 1. Quack token and Postgres password

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. `QUACK_TOKEN` in `.env`; one `kubectl create secret` in the `duckdb` namespace with the token and `POSTGRES_PASSWORD` | Same as [D-031](031-source-postgres-password-from-env.md) | One more command | None | Meets all requirements |
| B. DuckDB in the `postgres` namespace, reusing its Secret | Mixes two components | No password copy | None | Contradicts [D-032](032-one-application-per-component.md) |

### 2. Storage

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. In memory: DuckDB is the engine; data stays in Postgres and S3 | Fits its role; tables created in DuckDB are lost on restart | No volume | None | Meets all requirements |
| B. Database file on a PVC | Keeps DuckDB tables across restarts | One more volume and teardown item | About US$ 0.08/GiB-month | Meets all requirements |

### 3. Transport

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Plain HTTP (`disable_ssl = true`), ClusterIP only, reached through `kubectl port-forward` | Traffic stays in the cluster or the port-forward tunnel; protected by the token; Quack docs advise against internet exposure | Clients attach as `quack:localhost:9494` | None | Same access model as [D-012](012-cluster-and-ui-access.md) |
| B. HTTPS with a self-signed certificate | Encrypted inside the cluster too | Every client needs `SSL_FINGERPRINT` or a certificate | None | Meets all requirements |

### 4. Query UI

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. DuckDB UI on the user's computer, attaching the server through Quack | Uses Quack as designed | DuckDB 2.0 CLI installed locally | None | Meets all requirements |
| B. DuckDB UI inside the DuckDB pod (`start_ui_server()`), reached through `kubectl port-forward` | Two services in one process | Nothing to install; Postgres and S3 already attached | None | Same access model as D-012 |

## Decision

- **Recommended:** 1A, 2A, 3A and 4B: the same password pattern as Postgres, no volume, no
  certificates, and a UI with nothing to install.
- **Chosen:** 1A, 2A, 3A and 4B; 4A is documented in the phase README as the alternative UI.
- **Reason:** follows the recommendation.

## Sources

- [DuckDB: Quack FAQ](https://duckdb.org/quack/faq)
- [DuckDB 2.0: Quack overview](https://duckdb.org/docs/2.0/quack/overview.html)
- [DuckDB 2.0: Quack reference](https://duckdb.org/docs/2.0/quack/reference.html)
- [DuckDB 2.0: UI extension](https://duckdb.org/docs/2.0/core_extensions/ui.html)
- [Docker Hub: duckdb/duckdb](https://hub.docker.com/r/duckdb/duckdb)
