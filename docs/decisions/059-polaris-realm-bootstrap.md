# D-059 — How the Polaris Realm Is Bootstrapped

Status: Accepted
Date: 2026-11-09
Phase: specs/03-processing-spark-iceberg

## Context

Polaris ([D-044](044-iceberg-rest-catalog-server.md)) keeps its catalog in the catalog Postgres
([D-046](046-catalog-metadata-database.md)). Before Polaris can be used, its realm (its tenant,
`POLARIS`) must be bootstrapped: this creates Polaris's tables in the database and the root
credentials, a client ID and secret used to call Polaris's APIs. The Polaris admin tool
(`apache/polaris-admin-tool:1.8.0`) does it, and the command is idempotent: running it again on a
bootstrapped realm changes nothing. The choice is who runs it.

The root secret stays out of Git: it lives in `.env` and reaches the cluster as a Secret created
with `kubectl` ([D-031](031-source-postgres-password-from-env.md)).

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. The user runs the admin tool once with a documented `kubectl run` command | Best practice: the method in the Polaris Helm production guide | One command, run once after the catalog Postgres is up | None | Same flow as D-031 (manual `kubectl` steps documented) |
| B. A Kubernetes Job in Git, synced by Argo CD, runs the admin tool | No official best practice: the Polaris docs show no Job; checked the Polaris admin-tool and Helm production pages | One more manifest; retries until the database is ready | None | GitOps; nothing to remember |

## Decision

- **Recommended:** A, because it is the method of the official guide and adds no manifest; the
  bootstrap runs once per environment.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Polaris 1.8.0: Helm chart production guide (Bootstrapping Realms)](https://github.com/apache/polaris/blob/apache-polaris-1.8.0/site/content/in-dev/unreleased/helm-chart/production.md)
- [Polaris 1.8.0: Admin Tool (bootstrap is idempotent)](https://github.com/apache/polaris/blob/apache-polaris-1.8.0/site/content/in-dev/unreleased/admin-tool.md)
- [Polaris 1.8.0: Relational JDBC metastore](https://github.com/apache/polaris/blob/apache-polaris-1.8.0/site/content/in-dev/unreleased/metastores/relational-jdbc.md)
