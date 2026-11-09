# 04.02 — Airflow Image: Specification

Status: Approved
Phase: [04 — Orchestration: Airflow for Airbyte and Spark](../plan.md)

## Design

| Component | Configuration | ADR |
|---|---|---|
| Base image | `apache/airflow:3.4.0` (regular variant, Python 3.13) | [D-063](../../../docs/decisions/063-airflow-version.md), [D-068](../../../docs/decisions/068-airflow-base-image-variant.md) |
| Base pinning | Tag and digest `sha256:a8d9d19c…` | [D-069](../../../docs/decisions/069-airflow-base-image-pinning.md) |
| Added package | `apache-airflow-providers-airbyte` 6.2.0 | [D-066](../../../docs/decisions/066-airbyte-provider-installation.md) |
| Installation | With `apache-airflow==3.4.0` and the image's constraints file | [D-070](../../../docs/decisions/070-airbyte-provider-constraints.md) |
| Providers already in the base | `cncf-kubernetes` 10.25.0, `amazon` 9.39.0, `git` 1.0.1, `postgres` 7.1.1, `fab` 3.10.2 | [D-068](../../../docs/decisions/068-airflow-base-image-variant.md) |
| Dockerfile | `platform/images/airflow/Dockerfile` | [D-053](../../../docs/decisions/053-spark-dockerfile-location.md) |
| Repository link | Label `org.opencontainers.image.source` pointing to this repository, as in the Spark image | — |
| Image name | `ghcr.io/andrerosalopes/airflow:3.4.0-airbyte6.2.0` | [D-054](../../../docs/decisions/054-spark-image-tag.md) |
| Build and push | From the user's computer, logged in with the `gh` token | [D-055](../../../docs/decisions/055-spark-image-build.md) |
| Visibility | Public, set once on GitHub | [D-047](../../../docs/decisions/047-spark-dependencies.md) |

## Files

| File | Change |
|---|---|
| `platform/images/airflow/Dockerfile` | Create: the pinned base plus the Airbyte provider |
| `specs/04-orchestration-airflow/HOW_TO_RUN.md` | Modify: how to build and push the image |
| `specs/04-orchestration-airflow/README.md` | Modify: 04.02 section with the checks |
| `specs/04-orchestration-airflow/plan.md` | Modify: step status |

## Verification Plan

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | Image builds | `docker build` | Build succeeds | Pending |
| 2 | Automated | Versions fixed | `docker run` listing Airflow and its providers | Airflow 3.4.0; Airbyte provider 6.2.0; `airbyte-api` 1.0.1; the five base providers unchanged | Pending |
| 3 | Automated | Airbyte operator loads | `docker run` importing `AirbyteTriggerSyncOperator` | The import succeeds | Pending |
| 4 | Automated | Push | `docker push` with the `gh` token | Push ends with the image digest | Pending |
| 5 | Manual | Public package | GitHub → Your profile → Packages → `airflow` → Package settings → Change visibility → Public | The package shows as Public | Pending |
| 6 | Automated | Pull without login | `docker logout ghcr.io`, then `docker pull` | The pull succeeds | Pending |

## Teardown

No resource incurs cost.
