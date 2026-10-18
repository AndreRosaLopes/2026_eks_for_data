# D-016 — Bronze Bucket Versioning

Status: Accepted
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

AWS recommends turning on versioning in the raw (bronze) layer: it is the only copy of the data as
it arrived from the source, and versioning keeps overwritten or deleted objects recoverable (for
example, files removed by an Airbyte *Full Refresh | Overwrite* sync). The environment is destroyed
after use, and `force_destroy` deletes the bucket with all its versions.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Versioning on | AWS guidance for the raw layer; protects against overwrites and deletes, but only while the environment is up | One more setting; a lifecycle rule would be needed to expire old versions in a long-lived bucket | Each version billed as storage; negligible at this volume | Equivalent to blob versioning on Azure and object versioning on GCP |
| B. Versioning off (default) | Overwritten or deleted objects are lost; acceptable for an ephemeral environment whose data is lost on teardown anyway | Simplest | Zero | Meets all requirements |

## Decision

- **Recommended:** A, because it is AWS's guidance for the raw layer (principle 1).
- **Chosen:** B
- **Reason:** the environment is ephemeral and the bronze data is recreated by re-running the sync,
  so versioning adds little. This does not follow the principle priority order (simplicity over
  best practices).

## Sources

- [AWS Prescriptive Guidance: recommended data layers](https://docs.aws.amazon.com/prescriptive-guidance/latest/defining-bucket-names-data-lakes/data-layer-definitions.html)
- [Amazon S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
