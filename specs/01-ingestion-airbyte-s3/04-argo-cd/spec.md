# 01.04 — Argo CD: Specification

Status: Implemented
Phase: [01 — Ingestion: Airbyte Writing Parquet to S3](../plan.md)

## Design

Argo CD gets its own Terraform root, `infra/aws/gitops`
([D-003](../../../docs/decisions/003-terraform-root-layout.md)), with local state
([D-002](../../../docs/decisions/002-terraform-state-backend.md)). It is applied after
`infra/aws/cluster` and destroyed before it, and finds the cluster by name
(`data "aws_eks_cluster"`), with no wiring between the two states.

| Item | Value | Why |
|---|---|---|
| Providers | `hashicorp/aws ~> 6.59` (cluster data source) and `hashicorp/helm ~> 3.3` (3.3.0) | The helm provider authenticates with `exec` running `aws eks get-token`: temporary token, no saved kubeconfig; it uses the public endpoint, which accepts only `operator_cidr` |
| Argo CD | `helm_release` of the official `argo-cd` chart **10.10.5** (Argo CD **v3.5.5**) from `https://argoproj.github.io/argo-helm`, namespace `argocd` (`create_namespace = true`) ([D-007](../../../docs/decisions/007-argo-cd-installation.md)) | Latest stable, tested with Kubernetes 1.36 ([D-017](../../../docs/decisions/017-kubernetes-version.md)) |
| Chart values | Defaults, except `dex.enabled = false` | Dex only provides SSO, unused in the phase (login with the local `admin` user); one pod fewer |
| Resource requests | Chart defaults (none); usage measured in check 9 ([D-018](../../../docs/decisions/018-workload-resource-requests.md)) | Requests are set later from measured data |
| Root Application | `helm_release` of the official `argocd-apps` chart **2.0.7**, `depends_on` Argo CD. Application `platform`: repository `https://github.com/AndreRosaLopes/2026_eks_for_data.git` (public, no credentials), `targetRevision: main`, `path: platform/aws`, project `default`, destination in-cluster | App-of-apps: every Application in `platform/aws` (Airbyte in 01.05) is deployed by Argo CD. A separate chart because a `kubernetes_manifest` or `extraObjects` Application fails at plan time while the Argo CD CRDs do not exist yet |
| Sync | `automated` with `prune: true` and `selfHeal: true`; finalizer `resources-finalizer.argocd.argoproj.io` | GitOps: Git is the source of truth and manual drift is undone. The finalizer makes deleting `platform` also delete its children (including Airbyte's EBS volumes in 01.05) |
| `platform/aws/README.md` | Short note: each manifest in the folder is synced by the root Application | Git does not version empty folders, and Argo CD fails if the path does not exist; directory sources read only `.yaml`/`.yml`/`.json`, so the README is ignored |
| UI access | `kubectl -n argocd port-forward svc/argocd-server 8080:443` → `https://localhost:8080`, user `admin`, password from the `argocd-initial-admin-secret` Secret ([D-012](../../../docs/decisions/012-cluster-and-ui-access.md)) | Nothing exposed to the internet; the browser warns about the self-signed certificate |

**Order of the roots:** apply `cluster` then `gitops`. To destroy: first delete the `platform`
Application (`kubectl delete application platform -n argocd`, which waits for the cascade), then
destroy `gitops`, then `cluster`. Otherwise Argo CD can be removed before it finishes deleting its
children, leaving finalizers stuck and EBS volumes behind.

**Prerequisite:** step 01.03 applied (cluster up).

**Cost:** no AWS resources. The Argo CD pods (6) run on the Auto Mode nodes and may add one node
(EC2 + Auto Mode fee).

## Files

| File | Change |
|---|---|
| `infra/aws/gitops/providers.tf` | Create: versions, `aws` and `helm` providers, `data "aws_eks_cluster"` |
| `infra/aws/gitops/argocd.tf` | Create: `helm_release "argocd"` and `helm_release "argocd_apps"` (root Application `platform`) |
| `infra/aws/gitops/.terraform.lock.hcl` | Create (by `init`) |
| `platform/aws/README.md` | Create: purpose of the folder |

The phase README gets this step's section and the new root order in "Teardown"
(`/sdd-implement`).

## Verification Plan

Requires `AWS_PROFILE=eks-ws` and the kubeconfig for `eks-for-data`.

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | Formatting | `terraform -chdir=infra/aws/gitops fmt -check` | Exit 0 | Pass: exit 0 |
| 2 | Automated | Syntax | `terraform -chdir=infra/aws/gitops init && terraform -chdir=infra/aws/gitops validate` | `Success! The configuration is valid.` | Pass: `helm` 3.3.0, `aws` 6.70.0; valid |
| 3 | Automated | Plan | `terraform -chdir=infra/aws/gitops plan -out=tfplan` | 2 to add (`argocd`, `argocd_apps`), 0 to change, 0 to destroy | Pass: `2 to add, 0 to change, 0 to destroy` |
| 4 | Automated | Apply (**run by the user**) | `terraform -chdir=infra/aws/gitops apply tfplan` | `Apply complete! Resources: 2 added` | Pass: run by the user; `Resources: 2 added` |
| 5 | Automated | Argo CD pods | `kubectl -n argocd get pods` | `application-controller`, `applicationset-controller`, `notifications-controller`, `redis`, `repo-server`, `server` all `Running`/`Ready`; no `dex` | Pass: the 6 pods `Running` 1/1; no `dex` |
| 6 | Automated | Root Application | `kubectl -n argocd get application platform -o jsonpath='{.status.sync.status} {.status.health.status} {.spec.source.path}'` | `Synced Healthy platform/aws` | Pass: `Synced Healthy platform/aws` |
| 7 | Automated | Argo CD reads this repository | `.status.sync.revision` of `platform` vs. `git rev-parse origin/main` | Same commit | Pass: both `f51e532` |
| 8 | Automated | State outside Git | `git status --short` | Only the files listed above | Pass: clean (step files committed in `f51e532`) |
| 9 | Automated | Measured usage (D-018) | For each node running Argo CD pods: `kubectl get --raw /api/v1/nodes/<node>/proxy/stats/summary`, reading `memory.workingSetBytes` and `cpu.usageNanoCores` of the `argocd` pods, idle after sync | Usage per pod recorded in this column | Idle, one `c6a.large` node: application-controller 1m/73Mi; applicationset-controller 0m/21Mi; notifications-controller 0m/17Mi; redis 2m/5Mi; repo-server 1m/24Mi; server 1m/24Mi |
| 10 | Manual | UI by port-forward | Commands in the phase README: get the `admin` password, run the port-forward, open `https://localhost:8080`, accept the certificate | Login works; application `platform` **Synced** and **Healthy**, pointing to `platform/aws` | Pass: confirmed by the user |

## Teardown

```bash
set -a; source .env; set +a
kubectl delete application platform -n argocd   # cascades to child applications
terraform -chdir=infra/aws/gitops destroy
```

Then the cluster root (`infra/aws/cluster`) is destroyed.
