# D-017 — Kubernetes Version

Status: Accepted
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

Step 01.02 created the cluster with Kubernetes 1.37, the newest version on EKS. Argo CD 3.5.5, the
latest stable release, is tested only up to Kubernetes 1.36; Argo CD 3.6, which should add 1.37, is
still a release candidate (`v3.6.0-rc3`). The Airbyte chart (2.4.0) declares no Kubernetes version
constraint. The account is empty, so the next `apply` creates the cluster from scratch.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Keep 1.37 with Argo CD 3.5.5 | Untested combination; likely works (Argo CD uses stable APIs), but issues are ours to solve | No change | Same | Keeps step 01.02 unchanged |
| B. Kubernetes 1.36 with Argo CD 3.5.5 | Combination tested and supported on both sides; 1.36 is in EKS standard support until 2027-08-02 | One value changes; no downgrade, since the cluster is recreated; kubectl 1.37.1 stays within the allowed skew (1.35 to 1.37) | Same (no extended support) | Requires updating the 01.02 spec and the phase README |
| C. Keep 1.37 and wait for Argo CD 3.6 GA | Should be tested with 1.37 | Blocks step 01.04 with no known date | Same | Delays the phase |

## Decision

- **Recommended:** B, because running a combination tested by the vendors is the best practice
  (principle 1), for one changed value and the same cost. Moving to 1.37 can be a later step once
  Argo CD 3.6 is released.
- **Chosen:** B
- **Reason:** follows the recommendation.

## Sources

- [Argo CD 3.5: tested Kubernetes versions](https://github.com/argoproj/argo-cd/blob/v3.5.5/docs/operator-manual/tested-kubernetes-versions.md)
- [Argo CD releases](https://github.com/argoproj/argo-cd/releases)
- [Amazon EKS Kubernetes release calendar](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)
