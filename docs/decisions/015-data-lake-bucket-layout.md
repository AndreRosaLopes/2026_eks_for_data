# D-015 — Data Lake Bucket Layout

Status: Accepted
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

The data lake follows the medallion layers (bronze, silver, gold). In S3, they can be organized as
one bucket per layer or as prefixes in a single data bucket. The Airbyte internal bucket
([D-009](009-airbyte-internal-storage.md)) holds logs and state, not data, and stays separate in
both cases.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. One bucket per layer: `bronze` now, `silver` and `gold` in later phases | AWS guidance: "Each data layer must have an individual Amazon S3 bucket"; access policy, lifecycle and versioning per layer (Airbyte writes only bronze, business users read only gold); a permission mistake reaches only one layer | One bucket per phase; IAM by bucket | Same: S3 charges per GB and request, not per bucket | Equivalent to one container or storage account per layer on Azure and one bucket per layer on GCP |
| B. One data bucket with prefixes (`bronze/`, `silver/`, `gold/`) | Common in small projects; isolation depends on prefix policies (`bronze/*`), easier to get wrong; lifecycle and versioning apply to the whole bucket or need prefix filters | One bucket for all phases | Same | Also available on the three clouds |

## Decision

- **Recommended:** A, because it is AWS's explicit guidance (principle 1) and keeps per-layer
  permissions simple, at the same cost.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [AWS Prescriptive Guidance: recommended data layers](https://docs.aws.amazon.com/prescriptive-guidance/latest/defining-bucket-names-data-lakes/data-layer-definitions.html)
