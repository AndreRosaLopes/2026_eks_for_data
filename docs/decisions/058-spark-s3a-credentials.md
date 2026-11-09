# D-058 — How Spark Gets AWS Credentials to Read Bronze

Status: Accepted
Date: 2026-11-07
Phase: specs/03-processing-spark-iceberg

## Context

The job reads bronze through S3A, Hadoop's S3 connector ([D-052](052-aws-sdk-jars.md)). The pods get
AWS permissions through IRSA ([D-008](008-pod-aws-identity.md)): EKS places a token file in the pod,
and the AWS SDK exchanges it for credentials of the role `eks-for-data-spark`. The setting
`fs.s3a.aws.credentials.provider` tells S3A where to look for credentials.

S3A's default list in Hadoop 3.4.1 does not include IRSA, so without this setting the job cannot use
the Spark role.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. `WebIdentityTokenFileCredentialsProvider` | Uses only IRSA; if IRSA is missing, the job fails with a clear error | One setting | None | Meets D-008 |
| B. `DefaultCredentialsProvider` (the SDK's full chain) | Tries six sources in order, IRSA third; if IRSA is missing, it can fall back to another source, such as the node's role, and hide the mistake | One setting | None | Meets D-008; also works with EKS Pod Identity, which D-008 did not choose |

## Decision

- **Recommended:** A, because Spark uses exactly the role chosen in D-008, and a misconfiguration
  fails instead of falling back to another identity.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Hadoop 3.4.1: S3A (`fs.s3a.aws.credentials.provider` default)](https://hadoop.apache.org/docs/r3.4.1/hadoop-aws/tools/hadoop-aws/index.html)
- [AWS SDK for Java 2.x: default credentials provider chain](https://docs.aws.amazon.com/sdk-for-java/latest/developer-guide/credentials-chain.html)
