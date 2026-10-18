# D-018 — Workload Resource Requests

Status: Accepted
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

EKS Auto Mode (managed Karpenter) chooses and consolidates nodes by the pods' resource requests. The
Argo CD chart (10.10.5) ships with no requests or limits (`resources: {}`) in every component, and
no official sizing exists for small installations. Without requests, Karpenter does not account for
these pods, so a node can run out of memory once Airbyte (01.05) shares it. AWS recommends accurate
requests for every workload and, with consolidation, memory limits equal to memory requests.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Set estimated requests now (e.g., controller 250m/512Mi, repo-server 100m/256Mi, server 50m/128Mi) | Follows the "set requests" guidance, but not "accurate": the values are guesses, with no source | A few chart values | Too high reserves unused capacity; too low risks OOM | Same on AKS and GKE |
| B. Keep chart defaults, measure real usage, then set requests (CPU request only; memory request = limit) | Reaches accurate requests, as AWS recommends; until then, pods are not accounted for by Karpenter | One measuring check per step; values set once known | Sized from real data | Same on AKS and GKE |
| C. Never set requests | Against AWS guidance; OOM risk grows with Airbyte | Simplest | Unpredictable | Meets all requirements |

## Decision

- **Recommended:** B, because AWS asks for accurate requests (principle 1), and guessed values can
  waste capacity or cause OOM.
- **Chosen:** B
- **Reason:** follows the recommendation.
- **Revisit:** once the usage of Argo CD (01.04) and Airbyte (01.05) has been measured, set the
  requests and memory limits in a later step, or earlier if pods are evicted or OOM-killed.

## Sources

- [EKS best practices: Karpenter, scheduling pods](https://docs.aws.amazon.com/eks/latest/best-practices/karpenter.html)
- [EKS best practices: data plane, size resource requests and limits](https://docs.aws.amazon.com/eks/latest/best-practices/data-plane.html)
