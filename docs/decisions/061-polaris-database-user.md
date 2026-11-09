# D-061 — Catalog Database User for Polaris

Status: Accepted
Date: 2026-11-09
Phase: specs/03-processing-spark-iceberg

## Context

Polaris logs in to the catalog Postgres ([D-046](046-catalog-metadata-database.md)) as a database
user and keeps its tables in a schema (a named folder of tables inside the database) called
`polaris_schema`. The official `postgres` image always creates a superuser, a user with every right
on the whole database server. The choice is which user Polaris logs in as.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. A dedicated user `polaris`, with rights on `polaris_schema` only | Best practice: the Polaris JDBC docs require rights "on that schema only" | One more password in `.env` | None | Meets D-031, D-036 and D-046 |
| B. The superuser `postgres` | Against best practice: the Polaris JDBC docs require rights on the schema only | One password | None | Meets D-031 and D-046 |

Requirements checked (principle 7):

- [D-031](031-source-postgres-password-from-env.md): passwords in `.env` only. Both meet it.
- [D-036](036-airbyte-database-user.md): each application gets its own database user. Only A
  meets it.
- [D-046](046-catalog-metadata-database.md): Polaris has its own Postgres. Both meet it.

## Decision

- **Recommended:** A, because it is the best practice and costs only one more password.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Polaris 1.8.0: Relational JDBC metastore (schema and privileges)](https://github.com/apache/polaris/blob/apache-polaris-1.8.0/site/content/in-dev/unreleased/metastores/relational-jdbc.md)
- [Docker official image `postgres` (`POSTGRES_USER` creates a superuser)](https://hub.docker.com/_/postgres)
