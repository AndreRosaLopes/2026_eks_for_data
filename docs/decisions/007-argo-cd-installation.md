# D-007 — Argo CD Installation

Status: Accepted
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

Argo CD must be installed on the cluster and pointed at this repository to deploy the platform
components (GitOps).

Discarded: **EKS Capability for Argo CD (managed)**, because it has no GCP equivalent, requires
IAM Identity Center and is billed separately.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Official Helm chart via `helm_release` in the `gitops` root + root Application (app-of-apps) | Standard GitOps bootstrap | Public repository, so no credentials | Runs on the nodes | Identical on AKS and GKE |
| B. `kubectl apply` of `install.yaml` by script | Outside the Terraform state; manual teardown | Simple | Same | Weaker reproducibility |

## Decision

- **Recommended:** A, because it is the standard bootstrap and stays reproducible from Terraform.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Comparing EKS Capability for Argo CD to self-managed Argo CD](https://docs.aws.amazon.com/eks/latest/userguide/argocd-comparison.html)
- [Deep dive: EKS capability for Argo CD (IAM Identity Center required)](https://aws.amazon.com/blogs/containers/deep-dive-streamlining-gitops-with-amazon-eks-capability-for-argo-cd/)
