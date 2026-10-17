# D-013 — EKS Node Cost Tracking

Status: Accepted
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

The provider `default_tags` (`project`, `managed-by`) do not reach the EC2 instances that EKS Auto
Mode launches: the built-in NodePools and the `default` NodeClass cannot be modified. These nodes
are the largest cost of the phase.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. AWS-generated `aws:eks:cluster-name` tag (added by AWS to every cluster instance; activated in Billing) | Documented by AWS for per-cluster cost; does not cover the control plane, but the cluster itself gets the `project` tag | No code; built-in NodePools unchanged | Zero | Total cost needs two tags (`project` + `aws:eks:cluster-name`); AKS and GKE have equivalent cluster tags/labels |
| B. Custom NodeClass + NodePool with `spec.tags` (`project`, `managed-by`) + IAM tagging policy on the cluster role | Recommended by AWS for granular cost | Extra Kubernetes manifests and IAM permission; manifests only arrive with Argo CD (01.04), so nodes are untagged until then, or need a `kubectl apply` outside GitOps | Zero | One tag (`project`) covers everything; equivalent to tagged/labeled node pools on AKS and GKE |

## Decision

- **Recommended:** A, because both are best practices and A adds no code nor breaks the GitOps flow
  (principle 2), at the price of filtering cost by two tags.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Organize Amazon EKS resources with tags](https://docs.aws.amazon.com/eks/latest/userguide/eks-using-tags.html)
- [Create a Node Class for Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/create-node-class.html)
- [EKS Auto Mode cluster IAM role: custom AWS tags](https://docs.aws.amazon.com/eks/latest/userguide/auto-cluster-iam-role.html)
- [Maximizing value with Amazon EKS Auto Mode](https://aws.amazon.com/blogs/containers/maximizing-value-with-amazon-eks-auto-mode-strategies-for-visibility-control-and-optimization/) (default NodePools cannot be modified)
