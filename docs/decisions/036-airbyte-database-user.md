# D-036 — Airbyte Database User

Status: Accepted
Date: 2026-11-02
Phase: specs/02-transactional-ingestion

## Context

Airbyte needs its own Postgres user with read access and `REPLICATION` (CDC). Its password must
live only in `.env`, like the superuser password ([D-031](031-source-postgres-password-from-env.md)):
`.env` → Secret `postgres-credentials` (`kubectl`) → environment variable in the StatefulSet → used
on Postgres' first start (empty volume). At first start, `oltp` exists but has no tables; the
tables appear with `02-oltp-baseline.sql`, and each rerun drops and recreates them.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. User created by an init script from the Secret (`AIRBYTE_PG_PASSWORD`); `SELECT` on `oltp` granted at the end of `02-oltp-baseline.sql` | Least privilege, the Airbyte docs' form | Two places: init script and baseline | None | Same flow as D-031 |
| B. User and grants by a Kubernetes Job on every Argo CD sync | Least privilege; can change the password on a live environment | One more manifest, plus hooks ([D-019](019-airbyte-sync-policy.md)) | None | Meets all requirements |
| C. Airbyte uses `postgres` | Against least privilege: it can write and drop | Nothing to create | None | Meets all requirements |
| D. User created by an init script from the Secret, with `LOGIN REPLICATION` and the built-in role `pg_read_all_data` | Read-only, but on every schema (also `tpch`) | One place, created once; the baseline does not know about Airbyte | None | Same flow as D-031 |

## Decision

- **Recommended:** A, because it limits Airbyte to `oltp`, as the Airbyte docs do, and is simpler
  than B.
- **Chosen:** D
- **Reason:** the whole Airbyte user (creation, password and read access) lives in one place, is
  created once, and survives reruns of `02-oltp-baseline.sql`. It differs from the recommendation:
  read access is wider than needed (best practice set aside for simplicity). A password change on
  a live environment needs a manual `ALTER USER`.

## Sources

- [Airbyte: Postgres source (dedicated user, replication)](https://docs.airbyte.com/integrations/sources/postgres)
- [PostgreSQL: predefined roles (`pg_read_all_data`)](https://www.postgresql.org/docs/current/predefined-roles.html)
- [Docker official image `postgres`: initialization scripts](https://hub.docker.com/_/postgres)
