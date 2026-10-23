# How to Run

How to bring up the AWS environment and its services, pointing to the specs that hold each detail.
There are two ways to deploy the services on the cluster:

- **With Argo CD (GitOps):** the way the project is planned ([D-007](docs/decisions/007-argo-cd-installation.md)).
  Every service is a manifest in `platform/aws`, and Argo CD applies what is in Git.
- **Without Argo CD (manual):** `kubectl` for plain manifests and `helm` for charts, run from your
  terminal. It is **not part of the plan**: it does not meet the phase "Done When" ("Argo CD shows
  Airbyte `Synced` and `Healthy`") and is not verified by the specs.

## Status

Phase 01 is **done**: every step is implemented, and the Airbyte pipeline is a lab in the UI whose
configuration is not saved ([D-021](docs/decisions/021-airbyte-connection-ui-lab.md)).

| Step | What it brings up | Status |
|---|---|---|
| [01.01 — Network](specs/01-ingestion-airbyte-s3/01-network/spec.md) | VPC, subnets, NAT Gateways, S3 endpoint | Implemented |
| [01.02 — EKS cluster](specs/01-ingestion-airbyte-s3/02-eks-cluster/spec.md) | EKS Auto Mode cluster, Kubernetes 1.36 | Implemented |
| [01.03 — Data storage and access](specs/01-ingestion-airbyte-s3/03-data-storage/spec.md) | Bronze and Airbyte buckets, Airbyte IRSA role | Implemented |
| [01.04 — Argo CD](specs/01-ingestion-airbyte-s3/04-argo-cd/spec.md) | Argo CD and the root Application | Implemented |
| [01.05 — Airbyte](specs/01-ingestion-airbyte-s3/05-airbyte/spec.md) | StorageClass and Airbyte (with resource requests) | Implemented |
| [Lab 01 — API ingestion](specs/01-ingestion-airbyte-s3/lab01-api-ingestion.md) | PokeAPI → Parquet in the bronze bucket, created in the Airbyte UI | Lab (not saved) |

## Prerequisites

- The tools and access in the [phase README prerequisites](specs/01-ingestion-airbyte-s3/README.md#prerequisites).
- Manual path only: [Helm](https://helm.sh/docs/intro/install/) 3 and
  [yq](https://github.com/mikefarah/yq) 4, to read the chart values from the Argo CD manifests.

## 1. Infrastructure (both paths)

One Terraform root, `infra/aws/cluster`, creates the network, the cluster, the buckets and the
Airbyte IAM role (steps 01.01 to 01.03). Follow
[Turn On Again](specs/01-ingestion-airbyte-s3/README.md#turn-on-again) in the phase README
(about 15–20 minutes; cost starts running); for the manual path, stop before its
`infra/aws/gitops` commands.

What it creates and why: [01.01 design](specs/01-ingestion-airbyte-s3/01-network/spec.md#design),
[01.02 design](specs/01-ingestion-airbyte-s3/02-eks-cluster/spec.md#design),
[01.03 design](specs/01-ingestion-airbyte-s3/03-data-storage/spec.md#design).

## 2. Services with Argo CD

1. **Argo CD:** apply the `infra/aws/gitops` root after the cluster
   ([01.04 design](specs/01-ingestion-airbyte-s3/04-argo-cd/spec.md#design)):

   ```bash
   terraform -chdir=infra/aws/gitops init
   terraform -chdir=infra/aws/gitops plan -out=tfplan
   terraform -chdir=infra/aws/gitops apply tfplan
   ```

2. **Airbyte and the StorageClass:** they are manifests in `platform/aws`; Argo CD applies them after
   `git push` to `main` ([01.05 design](specs/01-ingestion-airbyte-s3/05-airbyte/spec.md#design)).
3. **Check:** `kubectl -n argocd get applications` shows `platform` and `airbyte` `Synced` and
   `Healthy`.

## 3. Services without Argo CD (manual)

Skip the `infra/aws/gitops` root. The manifests in `platform/aws` are still the source of the
configuration: plain manifests go through `kubectl`, and the chart values are read from the Argo CD
Application, so nothing is duplicated.

1. **StorageClass** (plain manifest):

   ```bash
   kubectl apply -f platform/aws/storageclass.yaml
   ```

2. **Airbyte** (Helm chart): extract the chart version and values from the Application, then install
   with `helm`:

   ```bash
   VERSION=$(yq '.spec.source.targetRevision' platform/aws/airbyte.yaml)
   yq '.spec.source.helm.valuesObject' platform/aws/airbyte.yaml > airbyte-values.yaml
   helm repo add airbyte https://airbytehq.github.io/charts
   helm install airbyte airbyte/airbyte --version "$VERSION" \
     --namespace airbyte --create-namespace --values airbyte-values.yaml --wait --timeout 15m
   rm airbyte-values.yaml
   ```

   The release name must be `airbyte`, as in Argo CD, so Service names match the specs.

3. **Check:** `kubectl -n airbyte get pods` shows every pod `Running`/`Ready` and the bootloader
   `Completed`.

**Why `helm` and not only `kubectl`:** Airbyte is a Helm chart, and some of its resources (database,
ServiceAccount, secrets, bootloader) are Helm hooks that must run in order before the rest. `helm
install` runs them in that order. `helm template ... | kubectl apply -f -` also works for simple
charts, but it applies everything at once and ignores the hooks, which can break the first start of
Airbyte.

**What you lose without Argo CD** (see [D-007](docs/decisions/007-argo-cd-installation.md)): Git
stops being the source of truth (the cluster keeps whatever the last command applied), manual
changes are not detected, and history lives only in `helm history`, which is lost on teardown.

**Adding other services later** follows the same pattern: `kubectl apply -f` for plain manifests and
`helm install` for charts (e.g., Trino, Airflow), each with its own infrastructure (buckets, IRSA
role) in Terraform.

## 4. Access

- **Argo CD UI** (Argo CD path): [01.04 section](specs/01-ingestion-airbyte-s3/README.md#0104--argo-cd)
  of the phase README.
- **Airbyte UI** (both paths): [01.05 section](specs/01-ingestion-airbyte-s3/README.md#0105--airbyte)
  of the phase README.

## 5. Pipeline (both paths)

Follow [Lab 01 — API ingestion](specs/01-ingestion-airbyte-s3/lab01-api-ingestion.md): source,
destination and connection created in the Airbyte UI, a sync, and the Parquet files checked in the
bronze bucket. Repeat it in every new environment.

## 6. Teardown

Delete the services **while the cluster is up**, so the Airbyte EBS volume is deleted with them;
then destroy the infrastructure.

- **With Argo CD:** [Turn Off](specs/01-ingestion-airbyte-s3/README.md#turn-off) in the phase README
  (applications, `airbyte` namespace, `gitops` root, then `cluster` root, in that order).
- **Without Argo CD:**

  ```bash
  helm uninstall airbyte --namespace airbyte
  kubectl delete namespace airbyte                       # PVC → EBS volume deleted
  kubectl delete -f platform/aws/storageclass.yaml
  ```

  Then [Turn Off](specs/01-ingestion-airbyte-s3/README.md#turn-off) in the phase README, skipping its
  Argo CD lines (`kubectl delete application`, `terraform -chdir=infra/aws/gitops destroy`).
