# D-050 — Spark Version

Status: Accepted
Date: 2026-11-07
Phase: specs/03-processing-spark-iceberg

## Context

The Spark image of [D-047](047-spark-dependencies.md) starts from an official Spark image, and its
version sets the jars: `hadoop-aws` must match that Spark release's Hadoop version, and the Iceberg
runtime must match its Spark line. The Spark Operator of [D-045](045-spark-on-kubernetes.md) runs
`spark-submit` with its own Spark (v2.5.2 is built from `apache/spark:4.0.4`); the driver and
executors run the image of D-047.

Discarded: Spark 4.2.1 and 4.3.0. Iceberg 1.12.0 has no runtime jar for them (README §2); 4.3.0 also
has no official Docker image.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Spark 4.0.5 | Latest patch (2026-10-27) of the line the operator uses | Jars: `iceberg-spark-runtime-4.0_2.13` 1.12.0, `hadoop-aws` 3.4.1. Operator and job on the same line | Same for all | Meets D-045, D-047 and the three clouds |
| B. Spark 4.1.4 | Newest line Iceberg supports | Jars: `iceberg-spark-runtime-4.1_2.13` 1.12.0, `hadoop-aws` 3.4.2. The operator's Spark 4.0.4 would start Spark 4.1.4 pods; a project member expects it to work (issue #2883), but it is untested until 03.04 | Same for all | Meets D-047 and the three clouds; D-045 untested with this version |
| C. Spark 4.0.4 | Exactly the operator's version, without the 4.0.5 patch | Same jars as A. Operator and job on the same version | Same for all | Meets D-045, D-047 and the three clouds |

## Decision

- **Recommended:** A, because it ties with C on best practices and adds the latest patch, and it is
  simpler than B, with no untested combination.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Apache Spark downloads](https://spark.apache.org/downloads.html)
- [Iceberg jars on Maven Central](https://repo1.maven.org/maven2/org/apache/iceberg/)
- Spark `pom.xml` for [v4.0.5](https://github.com/apache/spark/blob/v4.0.5/pom.xml) and [v4.1.4](https://github.com/apache/spark/blob/v4.1.4/pom.xml)
- [Spark Operator v2.5.2 Dockerfile](https://github.com/kubeflow/spark-operator/blob/v2.5.2/Dockerfile)
- [Spark Operator issue #2883](https://github.com/kubeflow/spark-operator/issues/2883)
