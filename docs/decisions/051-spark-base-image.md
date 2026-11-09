# D-051 — Spark Base Image

Status: Accepted
Date: 2026-11-07
Phase: specs/03-processing-spark-iceberg

## Context

The Spark image of [D-047](047-spark-dependencies.md) starts from an official Spark 4.0.5 image
([D-050](050-spark-version.md)); the base image is the one its Dockerfile names in `FROM`. D-050 set
the version, not the variant: publisher, Java runtime and Python. Facts that narrow it:

- The jobs are PySpark, so only `python3` variants qualify; the others are discarded.
- The EKS Auto Mode `general-purpose` node pool uses only `amd64`, and every candidate publishes it,
  so the architecture is not a choice.
- The Spark Operator v2.5.2 ([D-045](045-spark-on-kubernetes.md)) is built on `apache/spark:4.0.4`
  (Java 17).
- Both publishers build from the Spark project's Dockerfiles (`apache/spark-docker`).
- A tag can be moved to a new build: the image starts from `eclipse-temurin:17-jammy` and installs
  Ubuntu's `python3` package, so the Java patch and the Ubuntu packages change between builds. Only
  the digest (`@sha256:`) fixes the content.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. `apache/spark:4.0.5-python3` (Java 17) | Published by the Apache Spark project | Same publisher and Java as the operator image | Free; about 774 MB compressed | Meets D-045, D-047 and D-050 |
| B. `spark:4.0.5-python3` (Docker Official Image, Java 17) | Published by Docker from the Spark project's Dockerfiles | Different publisher from the operator image | Free | Meets D-045, D-047 and D-050 |
| C. `apache/spark:4.0.5-java21-python3` (Java 21) | Newer Java supported by Spark 4.0 | Different Java from the operator image | Free | Meets D-047 and D-050; differs from the operator's Java 17 |

## Decision

- **Recommended:** A, because it ties with B on best practices and is simpler: one publisher and one
  Java version for the operator and the jobs.
- **Chosen:** A, referenced by tag and digest (`apache/spark:4.0.5-python3@sha256:...`).
- **Reason:** follows the recommendation. The digest was added so every rebuild uses the same base
  (reproducibility); updating the base becomes an explicit change.

## Sources

- [Docker Hub: `apache/spark` tags](https://hub.docker.com/r/apache/spark/tags?name=4.0.5)
- [Docker Hub: `spark` (Docker Official Image) tags](https://hub.docker.com/_/spark/tags?name=4.0.5)
- [Apache Spark official Dockerfiles (`apache/spark-docker`)](https://github.com/apache/spark-docker)
  and its [`versions.json`](https://github.com/apache/spark-docker/blob/master/versions.json)
- [Spark v4.0.5 `pom.xml`](https://github.com/apache/spark/blob/v4.0.5/pom.xml)
- [EKS Auto Mode built-in node pools](https://docs.aws.amazon.com/eks/latest/userguide/set-builtin-node-pools.html)
