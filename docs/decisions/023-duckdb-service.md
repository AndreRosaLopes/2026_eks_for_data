# D-023 — DuckDB as a Service

Status: Accepted
Date: 2026-10-31
Phase: specs/02-transactional-ingestion

## Context

DuckDB must run as a permanent service in the cluster, reading and writing the source Postgres and
reading the Parquet files Airbyte writes to the bronze bucket. DuckDB is embedded by default, so it
needs a server mode. Discarded before the comparison: `harbor`, because it has no build for
DuckDB 2.0.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Quack (official DuckDB client-server protocol, core extension) | DuckDB's official solution; beta. Tested: `quack_serve` starts in 0.2 s, the process stays alive, a remote client attaches and queries | One SQL call; the client is DuckDB itself | One pod, no volume | Argo CD, IRSA (`CHAIN web_identity`), port-forward |
| B. `httpserver` (Query.Farm repository) | Third-party extension | Extra extension repository | Same | Meets all requirements |
| C. GizmoSQL | In maintenance mode | Helm + JDBC/ADBC driver | Same | Meets all requirements |

## Decision

- **Recommended:** A, because it is DuckDB's official solution and the simplest.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [DuckDB: Quack](https://duckdb.org/quack/)
- [DuckDB: Quack FAQ](https://duckdb.org/quack/faq)
- [httpserver extension](https://github.com/quackscience/duckdb-extension-httpserver)
