# D-040 — CDC Publication and Replica Identity

Status: Accepted
Date: 2026-11-02
Phase: specs/02-transactional-ingestion

## Context

`04-cdc-setup.sql` ([D-039](039-cdc-publication-and-slot-script.md)) creates the publication. The
publication can list tables or a whole schema, and the replica identity sets what the WAL holds for
an update or delete: only the primary key (`DEFAULT`) or the whole old row (`FULL`). Every `oltp`
table has a primary key.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. `CREATE PUBLICATION airbyte_publication FOR TABLE` with the 8 `oltp` tables, `REPLICA IDENTITY DEFAULT` | The exact form in the Airbyte docs | One statement, 8 names | Least WAL | Meets all requirements |
| B. `FOR TABLES IN SCHEMA oltp` (Postgres 15+), `DEFAULT` | Valid Postgres, not the form Airbyte documents | Shorter; new tables enter automatically | Same | Not verified with Airbyte |
| C. A with `REPLICA IDENTITY FULL` | Airbyte: only for rare cases (very large values) | 8 more statements | More WAL on every update | Meets all requirements |

## Decision

- **Recommended:** A, because it follows the Airbyte docs and writes the least WAL.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Airbyte: Postgres source (publication, replica identity)](https://docs.airbyte.com/integrations/sources/postgres)
- [PostgreSQL: CREATE PUBLICATION](https://www.postgresql.org/docs/current/sql-createpublication.html)
