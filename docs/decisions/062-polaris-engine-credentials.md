# D-062 — Polaris Credentials for Spark and DuckDB

Status: Accepted
Date: 2026-11-09
Phase: specs/03-processing-spark-iceberg

## Context

Spark (the writer) and DuckDB (the reader) log in to Polaris with a client ID and secret. Polaris
checks their rights through roles: a principal (an identity) gets a principal role, which gets a
catalog role, which holds privileges on the catalog. The root credentials of the bootstrap
([D-059](059-polaris-realm-bootstrap.md)) have every right in the realm. The plan leaves out
"catalog authentication beyond the minimum Polaris needs". The credentials stay in `.env` and reach
each pod as a Secret ([D-031](031-source-postgres-password-from-env.md)). The choice is which
credentials the engines use.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. One principal shared by Spark and DuckDB, with `CATALOG_MANAGE_CONTENT` on the lab catalog | Best practice: the Polaris "Using Polaris" guide connects engines with a principal of this kind, "not the root credentials" | Five CLI commands in the lab; one ID and secret | None | Meets the plan's scope, D-031 and D-049 |
| B. Two principals: Spark can manage content, DuckDB can only read | Best practice: same guide, plus least privilege per engine | About ten CLI commands; two IDs and secrets | None | Goes beyond the plan's out-of-scope limit on catalog authentication; meets D-031 and D-049 |
| C. Root credentials for both engines | Against best practice: the Polaris guide says engines use a principal, "not the root credentials" | No commands; one ID and secret | None | Meets the plan's scope and D-031 |

## Decision

- **Recommended:** A, because it is the form the official guide uses and stays within the plan's
  scope; B adds least privilege per engine, which the plan excludes.
- **Chosen:** A
- **Reason:** follows the recommendation. The principal, roles and privileges are created in the
  lab with the Polaris CLI, so the user can change them there (e.g., to B) without changing the
  infrastructure.

## Sources

- [Polaris 1.8.0: Using Polaris (principal, roles and `CATALOG_MANAGE_CONTENT`; Spark configuration)](https://github.com/apache/polaris/blob/apache-polaris-1.8.0/site/content/in-dev/unreleased/getting-started/using-polaris/_index.md)
- [Polaris 1.8.0: Role-Based Access Control](https://github.com/apache/polaris/blob/apache-polaris-1.8.0/site/content/in-dev/unreleased/managing-security/access-control.md)
