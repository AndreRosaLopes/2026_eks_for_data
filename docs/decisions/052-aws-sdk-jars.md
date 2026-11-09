# D-052 — AWS SDK Jars in the Spark Image

Status: Accepted
Date: 2026-11-07
Phase: specs/03-processing-spark-iceberg

## Context

The Spark image ([D-047](047-spark-dependencies.md), [D-051](051-spark-base-image.md)) carries two
components built on the AWS SDK for Java v2:

- **S3A** (`hadoop-aws` 3.4.1), Hadoop's S3 connector, reads bronze through `s3a://`. It is built
  against SDK 2.24.6 and needs the SDK transfer manager (`S3AFileSystem` imports
  `software.amazon.awssdk.transfer.s3`).
- **Iceberg S3FileIO** (`iceberg-spark-runtime-4.0_2.13` 1.12.0) writes silver. Its runtime jar has
  no SDK; the Iceberg docs offer `iceberg-aws-bundle` or the SDK `bundle` plus `apache5-client`.
  `iceberg-aws-bundle` 1.12.0 packs SDK 2.54.17, unshaded and without the transfer manager.

All jars share one classpath (`/opt/spark/jars`), where a duplicated class loads only once. The AWS
SDK policy says to "always use the same version across all AWS SDK dependencies". Hadoop says the
SDK modules S3A needs are "neither defined nor comes with any commitments".

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. `hadoop-aws` + SDK `bundle` 2.24.6 + `iceberg-aws-bundle` 1.12.0 | Two SDK versions on one classpath, which the AWS SDK policy warns against | 4 jars; which SDK copy loads is not controlled | About 627 MB of jars | Meets D-047, D-050 and D-051 |
| B. `hadoop-aws` + SDK `bundle` 2.54.17 + `apache5-client` 2.54.17 | One SDK version for both components, a route the Iceberg docs list | 4 jars | About 710 MB of jars | Meets D-047, D-050 and D-051; S3A on a newer SDK than it was built with, tested in 03.04 |
| C. `hadoop-aws` + `iceberg-aws-bundle` 1.12.0 + `s3-transfer-manager` 2.54.17 | One SDK version, but Hadoop does not define the modules S3A needs | 4 jars | About 70 MB of jars | Meets D-047, D-050 and D-051; a missing SDK module would show up only at runtime |

The 4 jars are the Iceberg runtime plus the three in each row. The image size costs cents in NAT data
processing per pull.

## Decision

- **Recommended:** B, because it is the only alternative with one SDK version and a complete SDK, on
  a route the Iceberg docs list. Its risk (S3A on SDK 2.54.17 instead of 2.24.6; the SDK says minor
  upgrades "SHOULD usually just work") is tested in 03.04.
- **Chosen:** B
- **Reason:** follows the recommendation.

## Sources

- [Hadoop 3.4.1 `hadoop-aws` POM](https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.4.1/hadoop-aws-3.4.1.pom) and [`hadoop-project` POM](https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-project/3.4.1/hadoop-project-3.4.1.pom)
- [Hadoop 3.4.1: S3A and the AWS SDK V2](https://hadoop.apache.org/docs/r3.4.1/hadoop-aws/tools/hadoop-aws/aws_sdk_upgrade.html)
- [Hadoop 3.4.1 `S3AFileSystem.java`](https://github.com/apache/hadoop/blob/rel/release-3.4.1/hadoop-tools/hadoop-aws/src/main/java/org/apache/hadoop/fs/s3a/S3AFileSystem.java)
- [Iceberg 1.12.0 AWS docs](https://github.com/apache/iceberg/blob/apache-iceberg-1.12.0/docs/docs/aws.md)
- Iceberg 1.12.0 [`aws-bundle/build.gradle`](https://github.com/apache/iceberg/blob/apache-iceberg-1.12.0/aws-bundle/build.gradle) and [`libs.versions.toml`](https://github.com/apache/iceberg/blob/apache-iceberg-1.12.0/gradle/libs.versions.toml)
- [AWS SDK for Java v2: Versioning Policy](https://github.com/aws/aws-sdk-java-v2/blob/master/VERSIONING.md)
- [Maven Central](https://repo1.maven.org/maven2/): jar sizes
