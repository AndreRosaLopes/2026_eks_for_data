# D-047 — Spark Dependencies

Status: Accepted
Date: 2026-11-02
Phase: specs/03-processing-spark-iceberg

## Context

The official Spark 4.0.4 image lacks the jars this phase needs: `hadoop-aws` (to read bronze through
`s3a://`), the Iceberg runtime for Spark 4.0 and the Iceberg AWS bundle. The choice is how they reach
the driver and executor pods.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. `spark.jars.packages`: the driver downloads the jars from Maven Central on every job run | Common in labs; every run depends on Maven Central; slow start | One line in the job | NAT data processing on every run (cents) | Same on every cloud |
| B. Custom image in Amazon ECR | Production practice: reproducible, fast start | ECR repository in Terraform, build and push, IAM for the push | About $0.10 per GB-month plus NAT on pull | AWS only: Azure and GCP need their own registries |
| C. Custom image in GitHub Container Registry (`ghcr.io`), built by GitHub Actions, public | Reproducible, fast start; common in open-source projects | A Dockerfile and one workflow file; no Terraform or IAM | Free for a public image, plus NAT on pull | One registry serves the three clouds |

## Decision

- **Recommended:** C, because it is a reproducible image (principle 1), free and multi-cloud, with
  no Terraform or IAM.
- **Chosen:** C
- **Reason:** chosen instead of ECR to make the project more compatible with, and simpler to bring
  to, the other clouds: one registry serves AWS, Azure and GCP.

## Sources

- [GitHub: Working with the Container registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Amazon ECR pricing](https://aws.amazon.com/ecr/pricing/)
- [Apache Spark: configuration (`spark.jars.packages`)](https://spark.apache.org/docs/latest/configuration.html)
