# D-028 — Lab02 Cursor

Status: Accepted
Date: 2026-10-31
Phase: specs/02-transactional-ingestion

## Context

Airbyte incremental sync by cursor (lab02) needs a column that changes whenever a row changes. TPC-H has no such column.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. `updated_at` in every `oltp` table, kept by a Postgres trigger on INSERT and UPDATE | Common OLTP pattern; no script can forget it | One trigger function | None | Meets all requirements |
| B. `updated_at` set by the scripts | Easy to forget in a statement | No trigger | None | Meets all requirements |
| C. `o_orderdate` as cursor | Misses updates | Simplest | None | Fails lab02 (updates) |

## Decision

- **Recommended:** A, because the database guarantees the column.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Airbyte: Postgres source](https://docs.airbyte.com/integrations/sources/postgres)
