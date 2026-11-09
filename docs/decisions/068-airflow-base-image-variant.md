# D-068 — Airflow Base Image Variant

Status: Accepted
Date: 2026-11-09
Phase: specs/04-orchestration-airflow

## Context

The custom Airflow image ([D-066](066-airbyte-provider-installation.md)) starts from an official
image, named in its Dockerfile `FROM`. Airflow 3.4.0 comes in two variants:

- **Regular** (`apache/airflow:3.4.0`): Python 3.13, 625 MB compressed. It already includes every
  provider this phase needs except Airbyte's: `cncf-kubernetes` 10.25.0 (KubernetesExecutor and
  Spark, [D-064](064-airflow-executor.md)), `amazon` 9.39.0 (task logs in S3), `git` 1.0.1
  (`GitDagBundle`, [D-067](067-dag-delivery.md)), `postgres` 7.1.1 (metadata database,
  [D-065](065-airflow-metadata-database.md)) and `fab` 3.10.2 (the chart's default login).
- **Slim** (`apache/airflow:slim-3.4.0`): Python 3.13, 249 MB compressed, with only the core and 5
  basic providers. Per the Airflow docs, you "need to add all the [...] providers that you need
  separately", and slim is "the most flexible way to build your image".

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Regular image plus the Airbyte provider | No official best practice: the Airflow image docs present both variants as bases for a custom image (checked: image docs index and "Building the image") | One package to add and pin | About 625 MB per pull, a few cents of NAT data processing | Meets D-063 to D-067 |
| B. Slim image plus the 6 providers it lacks (Airbyte, Kubernetes, Amazon, Git, Postgres, FAB) | No official best practice: same docs; slim lets you install only what you need and upgrade dependencies freely | Six packages to add, pin and keep compatible | About 250 MB plus the providers per pull | Meets D-063 to D-067 |

## Decision

- **Recommended:** A. No source names a best practice, so principles 2 and 3 decide: A needs one
  package instead of six; B's smaller pulls save only cents.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Airflow 3.4.0: Docker image docs (regular and slim)](https://github.com/apache/airflow/blob/3.4.0/docker-stack-docs/index.rst)
- [Airflow 3.4.0: building the image](https://github.com/apache/airflow/blob/3.4.0/docker-stack-docs/build.rst)
- [Docker Hub: `apache/airflow` tags (sizes and digests)](https://hub.docker.com/r/apache/airflow/tags?name=3.4.0)
- Images `apache/airflow:3.4.0` and `slim-3.4.0`, inspected locally: Python version and installed providers
