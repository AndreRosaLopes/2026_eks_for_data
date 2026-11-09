# D-063 — Airflow Version

Status: Accepted
Date: 2026-11-09
Phase: specs/04-orchestration-airflow

## Context

The project requires the newest Airflow version compatible with it:

- The latest release is 3.4.0, from 2026-11-06.
- The latest official Helm chart (the package that installs Airflow on Kubernetes) is 1.22.0, from
  2026-06-01. It installs 3.2.2 by default and declares support for "Airflow 3.0+".
- Both providers need Airflow 2.11 or later: `cncf-kubernetes` 10.25.0 (Spark) and `airbyte` 6.2.0
  (Airbyte).

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. 3.4.0 | Accepted practice: within the chart's declared support; a `.0` release, 3 days old | One image tag over the chart default | None | Meets all requirements; the newest |
| B. 3.3.2 | Accepted practice: the latest patch of the previous minor | One image tag over the chart default | None | Meets all requirements; not the newest |
| C. 3.2.2 | Best practice: the chart default, released together with it | No override | None | Meets all requirements; two minors behind |

## Decision

- **Recommended:** A, because it is the newest and the chart declares support for it. Step 04.03
  tests it; if it fails there, B is the fallback.
- **Chosen:** A
- **Reason:** follows the recommendation; the user asked for the newest compatible version.

## Sources

- [PyPI: apache-airflow](https://pypi.org/project/apache-airflow/)
- [Airflow Helm chart index](https://airflow.apache.org/index.yaml)
- [Chart 1.22.0 docs ("Supported Airflow version: 2.11+, 3.0+")](https://github.com/apache/airflow/blob/helm-chart/1.22.0/chart/docs/index.rst)
