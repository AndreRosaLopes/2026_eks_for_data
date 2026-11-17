# D-077 — Terraform Root Layout with a Persistent Data Root

Status: Accepted
Date: 2026-11-17
Phase: specs/05-lab-state-persistence

## Context

[D-003](003-terraform-root-layout.md) put the buckets in `infra/aws/cluster`, with
`force_destroy = true`, so `terraform destroy` deletes them. With [D-076](076-lab-state-persistence.md)
the buckets must survive while the cluster is destroyed. This decision supersedes D-003 and restates
the whole layout.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. New root `infra/aws/data` with the bronze, silver, Airbyte, Airflow and Velero buckets; `cluster` builds their names and ARNs from the fixed pattern `eks-for-data-<name>-<account>` | Roots split by lifecycle, the rule of D-003 | One more root, no wiring between roots | Same | Meets D-002, D-003's rule and D-015; `azure/` and `gcp/` repeat it |
| B. Buckets stay in `cluster`; the destroy skips them with `-target` or `terraform state rm` | Routine `-target` is advised against by HashiCorp | No new root, but a fragile destroy | Same | Weaker reproducibility: the destroy depends on a hand-kept list |
| C. `prevent_destroy` on the buckets | Not viable: it makes the whole `destroy` fail | — | — | Discarded |

## Decision

- **Recommended:** A, because it applies D-003's own rule (roots split by lifecycle).
- **Chosen:** A
- **Reason:** follows the recommendation.
- **Layout:** `infra/aws/data` (buckets; never destroyed by `down.sh`, only by the purge),
  `infra/aws/cluster` (VPC, EKS, IAM roles), `infra/aws/backup` (Velero,
  [D-078](078-velero-installation-and-restore-order.md)), `infra/aws/gitops` (Argo CD);
  `platform/aws` (Argo CD applications); `pipelines/` (data pipelines). Applied in this order and
  destroyed in reverse, `data` excepted. Each root keeps local state ([D-002](002-terraform-state-backend.md)),
  and no root that creates the cluster uses the Kubernetes provider.

## Sources

- [Terraform Kubernetes provider: stacking with managed Kubernetes cluster resources](https://github.com/hashicorp/terraform-provider-kubernetes/blob/main/docs/index.md)
- [Terraform: plan command, resource targeting](https://developer.hashicorp.com/terraform/cli/commands/plan#resource-targeting) (not re-read in this session)
