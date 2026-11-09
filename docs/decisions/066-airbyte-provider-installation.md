# D-066 — Airbyte Provider Installation

Status: Accepted
Date: 2026-11-09
Phase: specs/04-orchestration-airflow

## Context

Airflow tasks run inside the Airflow image; with the KubernetesExecutor
([D-064](064-airflow-executor.md)), every task starts a new pod of that image. The official image
`apache/airflow:3.4.0` already has the Spark operator (`cncf-kubernetes` 10.25.0) but not the Airbyte
operator (`apache-airflow-providers-airbyte` 6.2.0), which Airflow needs to call Airbyte's API.
Without the Airbyte integration, the official image would be enough. The Airflow docs give two
reasons against installing packages at startup (`_PIP_ADDITIONAL_REQUIREMENTS`): "every time any
container starts it must install new packages", and a package that changes or disappears on PyPI can
take "your production Airflow instance down, without you even knowing it"; their fix is "building
your own, immutable custom image, where the dependencies are baked in".

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Custom image: the official image plus the provider, built locally and pushed to `ghcr.io` | Best practice: the Airflow docs prescribe an "immutable custom image, where the dependencies are baked in" | A 2-line Dockerfile and two commands, as for Spark | None (public image) | Meets D-053, D-054 and D-055; a restart or a new environment runs the same image, with no PyPI dependency |
| B. `_PIP_ADDITIONAL_REQUIREMENTS`: the official image installs the provider in every container at startup | Against best practice: the Airflow docs say it "should only be used for testing" | One chart value; nothing to build | Every task pod starts slower | Meets all requirements; each start depends on PyPI |
| C. No provider: the DAG calls Airbyte's API with the HTTP operator, already in the official image | No official best practice: the Airflow docs document only the provider for Airbyte | Own DAG code for the token, the trigger and the polling | None | Meets all requirements; no custom image |

## Decision

- **Recommended:** A, because it is the practice the Airflow docs prescribe; an immutable image also
  gives a fast, predictable recovery.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Airflow 3.4.0: image entrypoint (`_PIP_ADDITIONAL_REQUIREMENTS`)](https://github.com/apache/airflow/blob/3.4.0/docker-stack-docs/entrypoint.rst)
- [Airflow 3.4.0: building the image](https://github.com/apache/airflow/blob/3.4.0/docker-stack-docs/build.rst)
- Image `apache/airflow:3.4.0`, inspected locally: installed providers
