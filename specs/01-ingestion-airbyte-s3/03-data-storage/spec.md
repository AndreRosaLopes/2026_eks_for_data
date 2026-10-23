# 01.03 — Data Storage and Access: Specification

Status: Implemented
Phase: [01 — Ingestion: Airbyte Writing Parquet to S3](../plan.md)

## Design

The buckets and the Airbyte role join the same `infra/aws/cluster` root
([D-003](../../../docs/decisions/003-terraform-root-layout.md): VPC, EKS, S3, IAM), built with
`terraform-aws-modules` ([D-004](../../../docs/decisions/004-terraform-modules.md)): `s3-bucket`
**5.17.0** and `iam` **6.8.2** (submodule `iam-role-for-service-accounts`).

| Item | Value | Why |
|---|---|---|
| Bronze bucket | `eks-for-data-bronze-<account_id>` | Raw data layer: destination of the Parquet files (phase lab); one bucket per layer ([D-015](../../../docs/decisions/015-data-lake-bucket-layout.md)). The account ID (`data "aws_caller_identity"`) makes the global name unique |
| Airbyte internal bucket | `eks-for-data-airbyte-<account_id>` | Airbyte logs, state and workload output, not data ([D-009](../../../docs/decisions/009-airbyte-internal-storage.md)); one bucket for the three chart keys `global.storage.bucket.{log,state,workloadOutput}` (01.05) |
| Bucket security | Module defaults: Block Public Access (all 4 on), ACLs disabled (`BucketOwnerEnforced`), S3 default encryption SSE-S3; plus `attach_deny_insecure_transport_policy = true` | No public access, encryption at rest, HTTPS only |
| Versioning | Off on both (module default; [D-016](../../../docs/decisions/016-bronze-bucket-versioning.md)) | Ephemeral environment; bronze data is recreated by re-running the sync |
| `force_destroy` | `true` on both | `terraform destroy` empties and deletes the buckets, as the teardown in "Done When" requires. **Bronze data is lost on teardown** |
| IRSA role | `eks-for-data-airbyte`, trusting `module.eks.oidc_provider_arn` for `airbyte:airbyte-admin` ([D-008](../../../docs/decisions/008-pod-aws-identity.md)) | `airbyte-admin` is the default `global.serviceAccountName` of chart 2.4.0, used by every pod, including sync jobs (`JOB_KUBE_SERVICEACCOUNT`); namespace `airbyte` (01.05) |
| Role policy | On both buckets (bucket and `/*`): `s3:PutObject`, `GetObject`, `DeleteObject`, `PutObjectAcl`, `ListBucket`, `ListBucketMultipartUploads`, `AbortMultipartUpload`, `GetBucketLocation` | The Airbyte S3 destination policy; also covers storage access with `authenticationType: instanceProfile` (default credential chain, so IRSA). No `s3:*`, no other buckets |

**Environment:** the account is empty after the teardown, so this step's `apply` also recreates the
network and the cluster (01.01 and 01.02): about 15–20 minutes, and cost back to about US$ 0.20/h
plus nodes. Buckets and the role cost cents or nothing.

## Files

| File | Change |
|---|---|
| `infra/aws/cluster/storage.tf` | Create: `data "aws_caller_identity"`, `module "s3_bronze"`, `module "s3_airbyte"`, `module "airbyte_irsa"` |
| `infra/aws/cluster/outputs.tf` | Modify: add `bronze_bucket`, `airbyte_bucket`, `airbyte_role_arn` (used in 01.05 and the phase lab) |
| `infra/aws/cluster/.terraform.lock.hcl` | Modify, if `init` changes it |

## Verification Plan

AWS commands use `--profile eks-ws --region us-east-1`; `TF_VAR_operator_cidr` must be exported.

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | Formatting | `terraform -chdir=infra/aws/cluster fmt -check` | Exit 0 | Pass: exit 0 |
| 2 | Automated | Syntax | `terraform -chdir=infra/aws/cluster init -upgrade && terraform -chdir=infra/aws/cluster validate` | `Success! The configuration is valid.` | Pass: valid; `init -upgrade` moved `aws` 6.69.1 → 6.70.0 and `tls` 4.4.1 → 4.4.2 in the lock file |
| 3 | Automated | Plan | `terraform -chdir=infra/aws/cluster plan -out=tfplan` | Network and EKS recreated, plus the 2 buckets (public access block, TLS policy) and the role with its policy; 0 to change, 0 to destroy | Pass: `64 to add, 0 to change, 0 to destroy` |
| 4 | Automated | Apply (**run by the user; incurs cost; ~15–20 min**) | `terraform -chdir=infra/aws/cluster apply tfplan` | `Apply complete!` | Pass: run by the user, no errors; 87 resources in state |
| 5 | Automated | Bucket security | `aws s3api get-public-access-block`, `get-bucket-encryption`, `get-bucket-ownership-controls`, `get-bucket-policy`, `get-bucket-versioning` on each bucket | 4 × `true`; `AES256`; `BucketOwnerEnforced`; `Deny` when `aws:SecureTransport=false`; versioning not enabled | Pass on both buckets: 4 × `True`; `AES256`; `BucketOwnerEnforced`; `Deny` on `aws:SecureTransport=false`; versioning `None` |
| 6 | Automated | Role trust | `aws iam get-role --role-name eks-for-data-airbyte` | Federated principal = cluster OIDC provider; `sub = system:serviceaccount:airbyte:airbyte-admin`; `aud = sts.amazonaws.com` | Pass: principal `oidc.eks.us-east-1.amazonaws.com/id/46D9…3015`; `sub` and `aud` as expected |
| 7 | Automated | Policy simulation | `aws iam simulate-principal-policy` on the role: `s3:PutObject` on both buckets and on `arn:aws:s3:::other-bucket/*` | `allowed` on both buckets; `implicitDeny` on the other | Pass: `allowed`, `allowed`, `implicitDeny` |
| 8 | Automated | IRSA in a real pod | Temporary namespace `airbyte` and SA `airbyte-admin` annotated with `eks.amazonaws.com/role-arn`; a `public.ecr.aws/aws-cli/aws-cli:2.38.1` pod runs `sts get-caller-identity`, writes, lists and deletes an object in each bucket, then `s3 ls` | Assumed role `eks-for-data-airbyte`; write, list and delete succeed; `s3 ls` → `AccessDenied` (no `ListAllMyBuckets`); namespace deleted at the end | Pass: `assumed-role/eks-for-data-airbyte`; write, list and delete ok on both buckets; `s3 ls` → `AccessDenied` (`s3:ListAllMyBuckets`); namespace deleted |
| 9 | Automated | State outside Git | `git status --short` | Only the files listed above | Pass: clean (step files committed in `4fe1e51`) |
| 10 | Manual | Buckets in the console | Console → **S3** → each `eks-for-data-*` bucket → **Permissions** and **Properties** tabs | **Block all public access: On**; **Default encryption: SSE-S3**; **Bucket Versioning: Disabled** | Pass: confirmed by the user |
| 11 | Manual | User writes to bronze as Airbyte would | Commands in the phase README: create namespace `airbyte` and the annotated SA `airbyte-admin`, run the aws-cli pod that writes `test/hello.txt` to the bronze bucket, see the file in the console, then delete the file and the namespace | The file appears in the console under `test/`; `kubectl logs` shows the upload | Pass: confirmed by the user |

## Teardown

```bash
set -a; source .env; set +a
export TF_VAR_operator_cidr="$(curl -s https://checkip.amazonaws.com)/32"
kubectl delete namespace airbyte --ignore-not-found   # test leftovers
terraform -chdir=infra/aws/cluster destroy
```

It empties and deletes both buckets (`force_destroy`) and deletes the role and its policy, together
with the cluster and the network.
