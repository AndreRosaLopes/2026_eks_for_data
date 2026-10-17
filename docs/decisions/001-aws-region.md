# D-001 — AWS Region

Status: Accepted
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

The platform needs one AWS region. There are no end users and no data residency requirement.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. `us-east-1` | Region with the most services and earliest launches | Same | Lowest prices | Meets all requirements; equivalent to Azure East US and GCP `us-east1` (same geography) |
| B. `sa-east-1` | Close to the operator (latency is irrelevant here) | Same | Higher EC2 and NAT prices (difference not measured per instance) | Meets all requirements |

## Decision

- **Recommended:** A, because it is cheaper with no loss on the other criteria.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Amazon EKS pricing](https://aws.amazon.com/eks/pricing/)
