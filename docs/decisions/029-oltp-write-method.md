# D-029 — OLTP Write Method and Deletes

Status: Accepted
Date: 2026-10-31
Phase: specs/02-transactional-ingestion

## Context

The trigger (D-028) and, later, the CDC publication are Postgres-only objects. The data copied into `oltp` is already inside Postgres.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Native Postgres SQL through `postgres_execute` for DDL and for every change in `oltp`; DuckDB for `dbgen` and checks; deletes explicit (line items, then the order) | Data stays in Postgres; triggers are native; every delete is visible in the script | Two SQL dialects | None | Meets all requirements |
| B. DuckDB SQL on the attached tables for data changes | One dialect for data changes | Rows travel Postgres → DuckDB → Postgres | None | Meets all requirements |
| C. A with `ON DELETE CASCADE` | One statement per delete | Line item deletes hidden | None | Meets all requirements |

## Decision

- **Recommended:** A, because it is fast and native, and explicit deletes keep the script readable.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [DuckDB: PostgreSQL extension](https://duckdb.org/docs/2.0/core_extensions/postgres/overview.html)
