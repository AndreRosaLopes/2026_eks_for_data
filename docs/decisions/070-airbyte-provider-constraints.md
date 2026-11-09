# D-070 — How the Airbyte Provider Is Installed in the Image

Status: Accepted
Date: 2026-11-09
Phase: specs/04-orchestration-airflow

## Context

The Dockerfile installs `apache-airflow-providers-airbyte` with `pip`, the Python package installer.
The provider pulls in other packages (such as the `airbyte-api` client), and `pip` may pick newer
versions of them, or even change Airflow's own version. Airflow publishes, for each release, a
constraints file: the full list of package versions tested together. The official image ships it
at `${HOME}/constraints.txt`; for 3.4.0 it already pins `apache-airflow-providers-airbyte==6.2.0`
and `airbyte-api==1.0.1`.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Install `apache-airflow==3.4.0` and the provider with the image's constraints file | Best practice: the Airflow docs say constraints give "the exact same installation of Airflow + providers + dependencies as was known to be working", and their example Dockerfile uses them | One `pip install` line; every dependency version fixed | None | Reproducible from Git, as [D-069](069-airflow-base-image-pinning.md) is for the base |
| B. Install `apache-airflow==3.4.0` and `apache-airflow-providers-airbyte==6.2.0`, without constraints | Accepted practice: the Airflow docs call pinning `apache-airflow` a "good practice" | One `pip install` line; the provider's own dependencies float | None | Two rebuilds can install different dependency versions |

## Decision

- **Recommended:** A, because it is the tested set the Airflow docs prescribe; every rebuild
  installs the same versions, which completes the reproducibility of D-069.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Airflow 3.4.0: installing from PyPI (constraints files)](https://github.com/apache/airflow/blob/3.4.0/airflow-core/docs/installation/installing-from-pypi.rst)
- [Airflow 3.4.0: building the image](https://github.com/apache/airflow/blob/3.4.0/docker-stack-docs/build.rst)
- [Airflow 3.4.0: example Dockerfile with constraints](https://github.com/apache/airflow/blob/3.4.0/docker-stack-docs/docker-examples/extending/add-pypi-packages-constraints/Dockerfile)
- [Constraints file for 3.4.0, Python 3.13](https://github.com/apache/airflow/blob/constraints-3.4.0/constraints-3.13.txt)
- Image `apache/airflow:3.4.0`, inspected locally: `${HOME}/constraints.txt`
