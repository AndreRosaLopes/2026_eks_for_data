# D-005 — Network Topology

Status: Accepted
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

The EKS cluster needs a VPC with subnets in at least two Availability Zones, and the nodes need
outbound internet access (container images, public API).

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. 2 AZs, nodes in private subnets, 1 NAT Gateway, S3 gateway endpoint (free) | Private nodes (EKS best practices); S3 traffic bypasses the NAT | Medium | NAT ~US$ 0.045/h + per GB | Equivalent to Azure NAT Gateway / Cloud NAT and service endpoint / Private Google Access |
| B. Public subnets only, no NAT | Exposed nodes, against best practice | Simplest | Cheapest | Meets all requirements |
| C. Same as A, with one NAT Gateway per AZ | High availability (production topology) | Same as A | Double NAT cost | High availability is not a goal (README §4) |

## Decision

- **Recommended:** A, because it keeps private nodes at the lowest cost.
- **Chosen:** C
- **Reason:** learn the production topology. High availability is a best practice even though
  the project has no availability requirement; the extra NAT cost is accepted.

## Sources

- [EKS best practices: networking](https://docs.aws.amazon.com/eks/latest/best-practices/networking.html)
