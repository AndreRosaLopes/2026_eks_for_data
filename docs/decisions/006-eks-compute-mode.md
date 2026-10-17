# D-006 — EKS Compute Mode

Status: Accepted
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

The cluster needs worker capacity for Argo CD and Airbyte, including EBS volumes for Airbyte's
Postgres ([D-009](009-airbyte-internal-storage.md)).

Discarded: **Fargate**, because it cannot mount EBS volumes or run DaemonSets.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. EKS Auto Mode | Current AWS model: managed Karpenter, EBS CSI, load balancer controller and Pod Identity; Bottlerocket nodes patched automatically | No node groups or add-ons; a `StorageClass` with `ebs.csi.eks.amazonaws.com` must be created | EC2 + management fee per instance | Equivalent to AKS Automatic (GA) and GKE Autopilot; Autopilot restrictions for Airbyte to be checked in the GCP phase |
| B. Managed node groups + add-ons | Classic and widely used | More configuration (add-ons, CSI IAM, scaling) | No fee | Equivalent to AKS node pools and GKE Standard |

## Decision

- **Recommended:** A, because both are best practices and A is much simpler; the fee is small
  for an ephemeral environment (cost is the last criterion).
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [EKS best practices: Auto Mode](https://docs.aws.amazon.com/eks/latest/best-practices/automode.html)
- [EKS Auto Mode: create a storage class](https://docs.aws.amazon.com/eks/latest/userguide/create-storage-class.html)
- [Amazon EKS pricing](https://aws.amazon.com/eks/pricing/)
