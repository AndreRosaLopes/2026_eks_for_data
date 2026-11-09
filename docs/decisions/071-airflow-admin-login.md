# D-071 — Airflow Admin Login

Status: Accepted
Date: 2026-11-09
Phase: specs/04-orchestration-airflow

## Context

Airflow's UI needs an admin user. The chart sets the FAB auth manager (the component that handles
logins), which keeps users in the metadata database, and creates the admin with a Job,
`createUserJob`. With Argo CD, the chart docs say you "must" set `createUserJob.useHelmHooks: false`,
so the Job runs as a normal resource. The Job takes the password from a chart value (default
`admin`), which both the chart docs and the project (AGENTS.md §1.5) rule out; the chart lets the Job
read environment variables from a Secret (`createUserJob.env` with `valueFrom`). Airflow's other auth
manager, Simple, is "intended for development and testing", per its docs.

Discarded: the password as a chart value, because it would put a secret in Git.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. The chart's `createUserJob`, reading the password from a Secret created from `.env` | Accepted practice: the chart's own mechanism, with the password kept out of the values, as the chart docs advise | Two overrides in the chart values (an environment variable and the password argument); no manual step | None | [D-031](031-source-postgres-password-from-env.md); the admin exists in every new environment with no extra command |
| B. No `createUserJob`; the user creates the admin once with a documented `kubectl exec`, password from `.env` | No official best practice: the chart docs don't describe this path (checked: chart docs index and production guide) | One command to remember in every new environment | None | Same manual pattern as the Polaris bootstrap ([D-059](059-polaris-realm-bootstrap.md)) |
| C. Simple auth manager instead of FAB | Against best practice: its docs say it is "intended for development and testing" | Users and passwords in a config file and a generated file | None | Changes the chart default |

## Decision

- **Recommended:** A, because it uses the chart's own mechanism, keeps the password out of Git and
  needs no manual step in a new environment. Not verified: whether `airflow users create` exits
  without error when the admin already exists (it matters if Argo CD reruns the Job); step 04.03
  tests it.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Chart 1.22.0: docs index ("Installing the Helm Chart with Argo CD")](https://github.com/apache/airflow/blob/helm-chart/1.22.0/chart/docs/index.rst)
- [Chart 1.22.0: `values.yaml` (`createUserJob`)](https://github.com/apache/airflow/blob/helm-chart/1.22.0/chart/values.yaml)
- [Chart 1.22.0: `_helpers.yaml` (`container_extra_envs` accepts `valueFrom`)](https://github.com/apache/airflow/blob/helm-chart/1.22.0/chart/templates/_helpers.yaml)
- [Airflow 3.4.0: Simple auth manager](https://github.com/apache/airflow/blob/3.4.0/airflow-core/docs/core-concepts/auth-manager/simple/index.rst)
