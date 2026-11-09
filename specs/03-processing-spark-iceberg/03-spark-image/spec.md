# 03.03 — Spark Image: Specification

Status: Implemented
Phase: [03 — Processing: Spark and Iceberg](../plan.md)

## Design

| Component | Configuration | ADR |
|---|---|---|
| Base image | `apache/spark:4.0.5-python3`, pinned by digest | [D-051](../../../docs/decisions/051-spark-base-image.md) |
| Iceberg jar | `iceberg-spark-runtime-4.0_2.13` 1.12.0 | [D-050](../../../docs/decisions/050-spark-version.md) |
| S3A jar | `hadoop-aws` 3.4.1 | [D-050](../../../docs/decisions/050-spark-version.md) |
| AWS SDK jars | `bundle` 2.54.17 and `apache5-client` 2.54.17 | [D-052](../../../docs/decisions/052-aws-sdk-jars.md) |
| HTTP client jars | `httpclient5` 5.6.4, `httpcore5` 5.4.3 and `httpcore5-h2` 5.4.3, required by `apache5-client` (added in 03.04) | [D-052](../../../docs/decisions/052-aws-sdk-jars.md) |
| Jar download | From Maven Central, each jar checked by SHA-256 | — |
| Dockerfile | `platform/images/spark/Dockerfile` | [D-053](../../../docs/decisions/053-spark-dockerfile-location.md) |
| Image name | `ghcr.io/andrerosalopes/spark:4.0.5-iceberg1.12.0` | [D-054](../../../docs/decisions/054-spark-image-tag.md) |
| Build and push | From the user's computer, with a GitHub token kept outside the repository | [D-055](../../../docs/decisions/055-spark-image-build.md) |
| Visibility | Public, set once on GitHub | [D-047](../../../docs/decisions/047-spark-dependencies.md) |
| Repository link | Label `org.opencontainers.image.source` pointing to this repository | — |

## Files

| File | Change |
|---|---|
| `platform/images/spark/Dockerfile` | Create: the base image plus the 7 jars |
| `specs/03-processing-spark-iceberg/HOW_TO_RUN.md` | Modify: how to build and push the image |
| `specs/03-processing-spark-iceberg/README.md` | Modify: 03.03 section with the checks |
| `specs/03-processing-spark-iceberg/plan.md` | Modify: step status |

## Verification Plan

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | Image builds | `docker build` | Build succeeds | Pass: built on 2026-11-09 with Docker 29.3.1 (amd64); every jar checksum matched |
| 2 | Automated | Jars present | `docker run` listing `/opt/spark/jars` | The 4 jars, one AWS SDK version | Pass: `iceberg-spark-runtime-4.0_2.13-1.12.0`, `hadoop-aws-3.4.1`, `bundle-2.54.17`, `apache5-client-2.54.17`; no other AWS SDK jar |
| 3 | Automated | Spark loads S3A and Iceberg | `docker run` with `pyspark` loading `S3AFileSystem` and `SparkCatalog`, and creating `WebIdentityTokenFileCredentialsProvider` | Both classes load; the provider is created | Pass: `S3AFileSystem`, `SparkCatalog` and `S3TransferManager` loaded. Re-run on 2026-11-09 after the HttpClient 5 fix (03.04): the provider is created; image digest `sha256:88fa4c6396c72b9e284b3f4cc2fe13cb23a2442e7bb341d62dcfdccac830fd6a` pushed |
| 4 | Manual | Push | `docker login ghcr.io`, then `docker push` | Push completes | Pass: pushed by the agent on 2026-11-09 with the `gh` token; digest `sha256:98168e63dbe79e22d69b03d3fe38ef73f7cace1f17cb4595d331d89c6fe0c250` |
| 5 | Manual | Public image | GitHub → Package settings → Change visibility → Public; then `docker pull` after `docker logout ghcr.io` | Pull succeeds without login | Pass: package set to Public by the user on 2026-11-09; after `docker logout ghcr.io`, the pull returned digest `sha256:98168e63…`, and an anonymous manifest request returned HTTP 200 |

## Teardown

No resource incurs cost.
