# 05.02 — Persistent Data Root: Specification

Status: Approved
Phase: [05 — Lab State Between Environments](../plan.md)

## Design

| Component | Configuration | ADR |
|---|---|---|
| Terraform root `infra/aws/data` | New root with local state | [D-077](../../../docs/decisions/077-persistent-data-root.md), [D-002](../../../docs/decisions/002-terraform-state-backend.md) |
| Buckets in `infra/aws/data` | bronze, silver, Airbyte and Airflow, moved from `infra/aws/cluster` unchanged | [D-077](../../../docs/decisions/077-persistent-data-root.md) |
| Velero bucket | `eks-for-data-velero-<account>`, new | [D-077](../../../docs/decisions/077-persistent-data-root.md) |
| Bucket settings | `force_destroy = true` | [D-082](../../../docs/decisions/082-persistent-bucket-deletion.md) |
| Bucket settings | Deny any access that is not over HTTPS | [D-015](../../../docs/decisions/015-data-lake-bucket-layout.md) |
| S3 module | `terraform-aws-modules/s3-bucket` 5.17.0 | [D-083](../../../docs/decisions/083-data-root-s3-module-version.md) |
| IAM roles in `infra/aws/cluster` | Bucket ARNs built from the pattern `eks-for-data-<name>-<account>` | [D-077](../../../docs/decisions/077-persistent-data-root.md) |
| `up.sh` | Applies `infra/aws/data` before `infra/aws/cluster` | [D-077](../../../docs/decisions/077-persistent-data-root.md) |
| `down.sh` | Does not destroy `infra/aws/data` | [D-077](../../../docs/decisions/077-persistent-data-root.md) |

## Files

| File | Change |
|---|---|
| `infra/aws/data/providers.tf` | Create: AWS provider and tags, the same as `cluster` |
| `infra/aws/data/buckets.tf` | Create: the five buckets |
| `infra/aws/data/outputs.tf` | Create: the bucket names, moved from `cluster` |
| `infra/aws/cluster/storage.tf` | Modify: remove the buckets; the roles use the built ARNs |
| `infra/aws/cluster/outputs.tf` | Modify: remove the bucket outputs |
| `scripts/up.sh` | Modify: apply `infra/aws/data` first |
| `scripts/down.sh` | Modify: the header comment says the buckets are kept |

## Verification Plan

No manual check: by the user's decision, every test of this phase is automated and run by the agent
(plan, Scope). This step skips the "at least one Manual check" rule.

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | Both roots are valid | `terraform validate` on `data` and `cluster` | Both valid | Pending |
| 2 | Automated | Bring-up creates the buckets | `up.sh`, then list the `eks-for-data-*` buckets | Five buckets | Pending |
| 3 | Automated | The services reach their buckets | `kubectl -n argocd get applications` | Every application `Synced` and `Healthy` | Pending |
| 4 | Automated | The roles point to the right buckets | Compare the ARNs in the IAM policies with the bucket names | Every ARN matches an existing bucket | Pending |
| 5 | Automated | Bronze and silver survive a teardown | Write a marker file to bronze and to silver, run `down.sh`, then read the markers | Both markers exist; no EKS cluster, NAT Gateway or VPC is left | Pending |
| 6 | Automated | A new bring-up keeps the buckets | `terraform plan` on `infra/aws/data` after `down.sh` | No changes | Pending |

## Teardown

- Cluster: `./scripts/down.sh`.
- Buckets (cents per month): `terraform -chdir=infra/aws/data destroy`. The purge in step 05.04
  automates this.
