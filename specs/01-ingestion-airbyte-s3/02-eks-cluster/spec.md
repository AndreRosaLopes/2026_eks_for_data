# 01.02 — EKS Cluster: Specification

Status: Approved
Phase: [01 — Ingestion: Airbyte Writing Parquet to S3](../plan.md)

## Design

The cluster joins the same `infra/aws/cluster` root
([D-003](../../../docs/decisions/003-terraform-root-layout.md)), built with the
`terraform-aws-modules/eks/aws` module **21.29.0** ([D-004](../../../docs/decisions/004-terraform-modules.md)),
on the private subnets of 01.01.

| Item | Value | Why |
|---|---|---|
| Name | `eks-for-data` (`local.name`) | |
| Kubernetes | `1.37`, the newest in standard support (until 2027-11-30) | Longest support window; avoids extended support charges |
| Compute | `compute_config = { enabled = true, node_pools = ["general-purpose"] }` ([D-006](../../../docs/decisions/006-eks-compute-mode.md)) | The `system` pool is tainted `CriticalAddonsOnly` and nothing in the phase needs it; in Auto Mode, CoreDNS, kube-proxy and the CNI run managed |
| Subnets | `module.vpc.private_subnets` | Private nodes ([D-005](../../../docs/decisions/005-network-topology.md)) |
| API endpoint | `endpoint_public_access = true`, `endpoint_public_access_cidrs = [var.operator_cidr]`; private access stays on (default) | [D-012](../../../docs/decisions/012-cluster-and-ui-access.md) |
| `operator_cidr` | Variable with no default, passed at apply time: `export TF_VAR_operator_cidr="$(curl -s https://checkip.amazonaws.com)/32"` | Home IPs change; if it changes, re-apply. Not a secret and not versioned |
| Authentication | `authentication_mode = "API"` + `enable_cluster_creator_admin_permissions = true` | Access entries only, no legacy `aws-auth` ConfigMap; `eks-ws-deployer` becomes cluster admin |
| OIDC (IRSA) | `enable_irsa = true` (module default) | [D-008](../../../docs/decisions/008-pod-aws-identity.md); used in 01.03 |
| API data encryption | `create_kms_key = false`, `encryption_config = null`: EKS default envelope encryption with an AWS owned key ([D-014](../../../docs/decisions/014-eks-api-data-encryption.md)) | No customer key, nothing left pending deletion on destroy |
| Control plane logs | Module default: `audit`, `api`, `authenticator` to CloudWatch, 90-day retention | Best practice (auditing); low cost at this traffic |
| Node cost | AWS-generated `aws:eks:cluster-name` tag ([D-013](../../../docs/decisions/013-eks-node-cost-tracking.md)), activated by the user in Billing together with `project` | |
| AWS provider | Constraint raised from `~> 6.28` to `~> 6.59` | The EKS module requires `>= 6.59`; the lock is already at 6.69.1 |

**Cost while running:** control plane US$ 0.10/h. Auto Mode creates nodes only while pods need
them (EC2 price + Auto Mode fee per node), and consolidation removes the empty node after the test.
CloudWatch logs cost cents. With the network: **about US$ 0.20/h without nodes**.

**New prerequisite:** kubectl **1.36 to 1.38** (the client supports one minor version of skew from
the cluster). Latest stable: `v1.37.1`.

## Files

| File | Change |
|---|---|
| `infra/aws/cluster/eks.tf` | Create: `module "eks"` |
| `infra/aws/cluster/variables.tf` | Create: `variable "operator_cidr"` |
| `infra/aws/cluster/outputs.tf` | Modify: add `cluster_name`, `oidc_provider_arn` (01.03) and `configure_kubectl` (the `aws eks update-kubeconfig` command) |
| `infra/aws/cluster/providers.tf` | Modify: `hashicorp/aws ~> 6.59` |
| `infra/aws/cluster/.terraform.lock.hcl` | Modify, if `init -upgrade` changes it |

## Verification Plan

AWS commands use `--profile eks-ws --region us-east-1`; `TF_VAR_operator_cidr` must be exported.

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | Formatting | `terraform -chdir=infra/aws/cluster fmt -check` | Exit 0 | Pass: exit 0 |
| 2 | Automated | Syntax | `terraform -chdir=infra/aws/cluster init -upgrade && terraform -chdir=infra/aws/cluster validate` | `Success! The configuration is valid.` | Pass; lock adds `cloudinit`, `null`, `time`, `tls` (used by the EKS module) |
| 3 | Automated | Plan | `terraform -chdir=infra/aws/cluster plan -out=tfplan` | Only EKS module creations (cluster, IAM roles, OIDC provider, access entry, log group, security groups); **0 to change, 0 to destroy** in the network | Pass: 31 to add, 0 to change, 0 to destroy; no KMS resources (D-014) |
| 4 | Automated | Apply (**run by the user; incurs cost; ~10–15 min**) | `terraform -chdir=infra/aws/cluster apply tfplan` | `Apply complete!` | Pending |
| 5 | Automated | Cluster | `aws eks describe-cluster --name eks-for-data` | `ACTIVE`, version `1.37`, `computeConfig.enabled=true`, `nodePools=[general-purpose]`, `publicAccessCidrs=[<operator IP>/32]`, private subnets only, `project` tag | Pending |
| 6 | Automated | OIDC provider | `aws iam list-open-id-connect-providers` | Includes the cluster issuer | Pending |
| 7 | Automated | Access entry | `aws eks list-associated-access-policies --cluster-name eks-for-data --principal-arn <eks-ws-deployer ARN>` | `AmazonEKSClusterAdminPolicy`, cluster scope | Pending |
| 8 | Automated | kubectl | `aws eks update-kubeconfig --name eks-for-data` and `kubectl auth can-i '*' '*' --all-namespaces` | `yes` | Pending |
| 9 | Automated | Test pod + NAT egress (pending from 01.01) | `kubectl run nat-test --image=public.ecr.aws/docker/library/busybox:1.37 --restart=Never -- wget -qO- https://pokeapi.co/api/v2/pokemon/ditto`; then `kubectl logs nat-test`, `kubectl get nodes -o wide`, `kubectl delete pod nat-test` | Pod `Completed`; log has the `ditto` JSON; the node has a `10.0.x` InternalIP (private subnet) and no external IP | Pending |
| 10 | Automated | State outside Git | `git status --short` | Only the files listed above appear | Pending |
| 11 | Manual | Cluster in the console | AWS console (N. Virginia) → **EKS** → `eks-for-data` | Status `Active`, Kubernetes `1.37`, **EKS Auto Mode** enabled | Pending |
| 12 | Manual | User runs a pod | `kubectl run hello --image=public.ecr.aws/docker/library/busybox:1.37 --restart=Never -- echo hello`; `kubectl logs hello`; `kubectl delete pod hello` | `hello` | Pending |
| 13 | Manual | Cost tags (D-013) | Console → **Billing and Cost Management** → **Cost allocation tags**: activate `aws:eks:cluster-name` (AWS-generated) and `project` (user-defined) | Both `Active` (may take up to 24 h to appear in the list) | Pending |

## Teardown

```bash
set -a; source .env; set +a
export TF_VAR_operator_cidr="$(curl -s https://checkip.amazonaws.com)/32"
kubectl delete pod --all          # make sure no test pods keep nodes alive
terraform -chdir=infra/aws/cluster destroy
```

It removes the cluster, Auto Mode nodes, IAM roles, OIDC provider and log group, and also the
network of 01.01.
