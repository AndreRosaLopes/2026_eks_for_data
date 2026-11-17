# D-083 — S3 Module Version in the Data Root

Status: Accepted
Date: 2026-11-17
Phase: specs/05-lab-state-persistence

## Context

The five buckets move to `infra/aws/data`. They use the community module
`terraform-aws-modules/s3-bucket`, which is pinned today to 5.17.0. The latest version is 5.17.1,
published on 2026-11-16; its changelog was not read.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. 5.17.0 (current) | No official best practice on which version to pin; both are exact pins | The code moves unchanged | Same | Meets all requirements |
| B. 5.17.1 (latest) | No official best practice: same | One extra change, with a changelog not yet read | Same | Meets all requirements |

## Decision

- **Recommended:** A. With no official best practice, principle 2 (simplicity) decides: the move
  changes only where the code lives.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Terraform Registry API: s3-bucket module](https://registry.terraform.io/v1/modules/terraform-aws-modules/s3-bucket/aws): latest version 5.17.1, published on 2026-11-16
- `infra/aws/cluster/storage.tf`: current pin 5.17.0
