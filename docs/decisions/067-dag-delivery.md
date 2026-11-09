# D-067 — DAG Delivery

Status: Accepted
Date: 2026-11-09
Phase: specs/04-orchestration-airflow

## Context

DAGs live in `pipelines/airflow/dags/` (README §6), and the repository is public. Airflow 3 reads
DAGs through DAG bundles, sources Airflow itself manages. `LocalDagBundle` (a local folder, the
default) is, per the docs, "ideal for development and testing environments", because it does not
support versioning. `GitDagBundle` fetches the DAGs from a Git repository and "does support
versioning": a DAG run uses the same code from start to end. The official image already has the Git
provider 1.0.1 (the latest) and `git` 2.47.3. The Helm chart documents the Airflow 2 methods, which
fill a local folder read by `LocalDagBundle`: git-sync, DAGs baked into the image, or a shared
volume.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. `GitDagBundle`: Airflow fetches `pipelines/airflow/dags/` from the public repository, branch `main` | Best practice: the Airflow 3 mechanism, with versioning; the docs reserve `LocalDagBundle` for development and testing | One config entry; no sidecar or volume; no credentials (public repository) | None | Pipeline code apart from the image (README §6), as in [D-048](048-spark-job-code-delivery.md) |
| B. git-sync sidecar (chart), filling a local folder | Accepted practice: documented in the chart, but ends in a `LocalDagBundle`, without versioning | A sidecar in every Airflow pod; a few chart values | None | Pipeline code apart from the image |
| C. DAGs baked into the custom image | Accepted practice: documented in the chart; a `LocalDagBundle`, without versioning | Every DAG change means a rebuild and a push | None | Mixes pipeline code into the platform image |
| D. git-sync with a shared volume (`ReadWriteMany`) | Accepted practice: documented in the chart; a `LocalDagBundle`, without versioning | Needs a shared-volume service (EFS on AWS) | EFS cost | A different storage service per cloud |

## Decision

- **Recommended:** A, because it is the Airflow 3 way to read DAGs from Git, the only one with
  versioning, and it needs no extra component.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Airflow 3.4.0: DAG bundles](https://github.com/apache/airflow/blob/3.4.0/airflow-core/docs/administration-and-deployment/dag-bundles.rst)
- [Chart 1.22.0: managing DAG files](https://github.com/apache/airflow/blob/helm-chart/1.22.0/chart/docs/manage-dag-files.rst)
- [PyPI: apache-airflow-providers-git](https://pypi.org/project/apache-airflow-providers-git/)
- Image `apache/airflow:3.4.0`, inspected locally: `apache-airflow-providers-git` 1.0.1, `git` 2.47.3
