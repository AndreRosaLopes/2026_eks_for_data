# D-003 — Repository and Terraform Root Layout

Status: Accepted
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

The infrastructure (network, cluster, Argo CD) and the data pipelines (Airbyte connections) must be
organized in the monorepo, keeping infrastructure and pipeline changes separate (README §6).

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Roots by lifecycle: `infra/aws/bootstrap`, `infra/aws/cluster` (VPC, EKS, S3, IAM), `infra/aws/gitops` (Argo CD); `platform/aws` (Argo CD apps); `pipelines/airbyte/aws` (connections) | Follows HashiCorp's warning that cluster resources "SHOULD NOT be created in the same Terraform module where Kubernetes provider resources are also used" | 4 roots, applied in order | Same | Separates infrastructure and pipeline streams; the `aws/` layout repeats for `azure/` and `gcp/` |
| B. One root for cluster and Argo CD | Violates the warning above (fragile on recreate or destroy) | Fewer roots | Same | Separates streams only if the pipeline root stays apart |
| C. One root per layer (network, eks, storage, argocd) with `terraform_remote_state` | Valid | More files and wiring between roots | Same | Meets all requirements |

## Decision

- **Recommended:** A, because it follows the provider's guidance and keeps the change streams apart.
- **Chosen:** A, without `infra/aws/bootstrap`, since [D-002](002-terraform-state-backend.md)
  chose local state.
- **Reason:** follows the recommendation.

## Sources

- [Terraform Kubernetes provider: stacking with managed Kubernetes cluster resources](https://github.com/hashicorp/terraform-provider-kubernetes/blob/main/docs/index.md)
