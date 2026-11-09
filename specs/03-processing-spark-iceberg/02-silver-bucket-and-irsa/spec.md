# 03.02 — Silver Bucket and IRSA Roles: Specification

Status: Implemented
Phase: [03 — Processing: Spark and Iceberg](../plan.md)

## Design

Everything lives in the existing Terraform root `infra/aws/cluster` (`storage.tf`, `outputs.tf`), in
the style of the bronze bucket and the DuckDB role:

| Resource | Name | Configuration |
|---|---|---|
| **Silver bucket** (`terraform-aws-modules/s3-bucket` 5.17.0) | `eks-for-data-silver-283429977024` | `force_destroy = true`, deny insecure transport, versioning off as bronze ([D-016](../../../docs/decisions/016-bronze-bucket-versioning.md)) ([D-015](../../../docs/decisions/015-data-lake-bucket-layout.md)) |
| **Spark IRSA role** (`terraform-aws-modules/iam` `iam-role-for-service-accounts` 6.8.2) | `eks-for-data-spark` | Trusts ServiceAccount `spark:spark` (namespace `spark`, used in 03.04). Bronze read only: `s3:GetObject`, `s3:ListBucket`, `s3:GetBucketLocation` |
| **Polaris IRSA role** (same module) | `eks-for-data-polaris` | Trusts ServiceAccount `polaris:polaris` (namespace `polaris`, used in 03.05). Only `sts:AssumeRole` on the silver data role |
| **Silver data role** (`aws_iam_role` and an inline policy) | `eks-for-data-silver-data` | Trusts only the Polaris role. Read and write on silver: `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket`, `s3:GetBucketLocation`, `s3:AbortMultipartUpload`, `s3:ListBucketMultipartUploads`. Polaris narrows them per table when it vends credentials ([D-049](../../../docs/decisions/049-silver-storage-credentials.md)) |
| **Outputs** | — | `silver_bucket`, `spark_role_arn`, `polaris_role_arn`, `silver_data_role_arn` |

The ServiceAccount names are fixed here because the role trust needs them; if the Polaris chart
(03.05) uses another name, 03.05 changes the trust.

Cost: an empty bucket and IAM roles cost nothing; silver data costs cents in S3.

## Files

| File | Change |
|---|---|
| `infra/aws/cluster/storage.tf` | Modify: `s3_silver`, `spark_irsa`, `polaris_irsa`, the silver data role and its policy |
| `infra/aws/cluster/outputs.tf` | Modify: the 4 outputs |
| `HOW_TO_RUN.md` | Modify: §5.1 Turn Off table (silver bucket and the new roles); phase 03 row in "1. Phases" |
| `specs/03-processing-spark-iceberg/HOW_TO_RUN.md` | Create from the template (nothing to run yet; links to Bring Up) |
| `specs/03-processing-spark-iceberg/README.md` | Create with the 03.02 section: every check as separate commands, one per block, with its expected result |
| `specs/03-processing-spark-iceberg/plan.md` | Modify: step status |

## Verification Plan

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Manual | Plan adds only | [README 03.02](../README.md#0302--silver-bucket-and-irsa-roles), step 1: `terraform plan` | `Plan: 11 to add, 0 to change, 0 to destroy` | Pass: confirmed by the user |
| 2 | Manual | Apply and bucket | README 03.02, steps 2 and 3: `terraform apply`, then `get-bucket-versioning` and `get-bucket-policy` on silver | Apply adds 11; versioning prints nothing (never enabled); policy denies `aws:SecureTransport` `false` | Pass: confirmed by the user (`Deny` with `"Condition":{"Bool":{"aws:SecureTransport":"false"}}`) |
| 3 | Manual | Spark role | README 03.02, step 4: temporary `aws-cli` pod in namespace `spark`, ServiceAccount `spark`: list bronze, then write to silver | Bronze listed; silver write `AccessDenied` | Pass: confirmed by the user; bronze listed `PRE oltp_cursor/` (the pod finished before `kubectl` attached, so the listing was read from the pod log) |
| 4 | Manual | Role chain | README 03.02, step 5: temporary `aws-cli` pod in namespace `polaris`, ServiceAccount `polaris`: assume the silver data role, put and delete a test object in silver | `put ok`, `delete ok` | Pass: run by the agent on 2026-11-09 (`put ok`, `delete ok`); namespace `polaris` deleted |
| 5 | Manual | AWS console | README 03.02, step 6: S3 bucket `eks-for-data-silver-283429977024`; IAM roles `eks-for-data-spark`, `eks-for-data-polaris`, `eks-for-data-silver-data`; the data role's **Trust relationships** name only `eks-for-data-polaris` | All present; trust as described | Pass: confirmed by the user on 2026-11-09 |

## Teardown

- The bucket and the roles go with `terraform -chdir=infra/aws/cluster destroy` at
  [Turn Off](../../../HOW_TO_RUN.md#51-turn-off); `force_destroy` empties the bucket.
- The temporary namespaces of checks 3 and 4 (`spark`, `polaris`) are deleted right after the checks.
