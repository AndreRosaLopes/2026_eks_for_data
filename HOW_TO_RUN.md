# How to Run

The home page for operating the platform: bring the environment up, open each service, run each
phase and tear everything down. Each phase has its own **Run** page (what to execute) and
**Verify** page (the checks and expected results).

There are two ways to deploy the services on the cluster:

- **With Argo CD (GitOps):** the way the project is planned ([D-007](docs/decisions/007-argo-cd-installation.md)).
  Every service is a manifest in `platform/aws`, and Argo CD applies what is in Git.
- **Without Argo CD (manual):** `kubectl` for plain manifests and `helm` for charts, run from your
  terminal. It is **not part of the plan**: it does not meet the phase "Done When" ("Argo CD shows
  Airbyte `Synced` and `Healthy`") and is not verified by the specs.

## 1. Phases

| Phase | Status | Run | Verify |
|---|---|---|---|
| 01 — Ingestion: Airbyte writing Parquet to S3 | Done | [Run](specs/01-ingestion-airbyte-s3/HOW_TO_RUN.md) | [Verify](specs/01-ingestion-airbyte-s3/README.md) |
| 02 — Transactional ingestion: TPC-H in Postgres, cursor and CDC | In progress (02.01–02.09 done) | [Run](specs/02-transactional-ingestion/HOW_TO_RUN.md) | [Verify](specs/02-transactional-ingestion/README.md) |
| 03 — Processing: Spark and Iceberg | In progress (03.01 to 03.04 done) | [Run](specs/03-processing-spark-iceberg/HOW_TO_RUN.md) | [Verify](specs/03-processing-spark-iceberg/README.md) |

## 2. Prerequisites

- AWS account access through the `eks-ws` profile (see `.env`)
- AWS console access to the same account, region `us-east-1`
- Git Bash in the repository root, with the `.env` variables loaded (Bash syntax; it does not work
  in PowerShell): `set -a; source .env; set +a`
- kubectl 1.35 to 1.37 (`kubectl version --client`)
- Manual path only: [Helm](https://helm.sh/docs/intro/install/) 3 and
  [yq](https://github.com/mikefarah/yq) 4, to read the chart values from the Argo CD manifests

## 3. Bring Up

### 3.1 Infrastructure (both paths)

The `infra/aws/cluster` root creates the network, the EKS cluster, the buckets and the IAM roles.

1. Load the `.env` variables:

   ```bash
   set -a; source .env; set +a
   ```

2. Check the AWS account; it must print `283429977024`:

   ```bash
   aws sts get-caller-identity --query Account --output text
   ```

3. Create the infrastructure (about 15–20 minutes; cost starts running). Terraform allows only your
   public IP to reach the EKS API:

   ```bash
   terraform -chdir=infra/aws/cluster init
   ```

   ```bash
   terraform -chdir=infra/aws/cluster plan -out=tfplan
   ```

   ```bash
   terraform -chdir=infra/aws/cluster apply tfplan
   ```

4. Point `kubectl` to the cluster:

   ```bash
   aws eks update-kubeconfig --name eks-for-data --region us-east-1
   ```

What it creates and why: [01.01 design](specs/01-ingestion-airbyte-s3/01-network/spec.md#design),
[01.02 design](specs/01-ingestion-airbyte-s3/02-eks-cluster/spec.md#design),
[01.03 design](specs/01-ingestion-airbyte-s3/03-data-storage/spec.md#design).

### 3.2 Services with Argo CD

1. **Passwords:** send them from `.env` to the cluster before Argo CD syncs Postgres and DuckDB.
   **Source Postgres password** ([D-031](docs/decisions/031-source-postgres-password-from-env.md)):
   if `.env` has no `POSTGRES_PASSWORD` yet, generate one (recommended: 32 hexadecimal characters,
   safe in connection strings) and load `.env` again:

   ```bash
   echo "POSTGRES_PASSWORD=$(openssl rand -hex 16)" >> .env
   ```

   ```bash
   set -a; source .env; set +a
   ```

   ```bash
   kubectl create namespace postgres
   ```

   **Airbyte database user** ([D-036](docs/decisions/036-airbyte-database-user.md)): if `.env` has
   no `AIRBYTE_PG_PASSWORD` yet, generate it the same way and load `.env` again. Postgres creates the
   `airbyte` user with it on its first start, so it goes in the same Secret:

   ```bash
   echo "AIRBYTE_PG_PASSWORD=$(openssl rand -hex 16)" >> .env
   ```

   ```bash
   set -a; source .env; set +a
   ```

   ```bash
   kubectl -n postgres create secret generic postgres-credentials --from-literal=password="$POSTGRES_PASSWORD" --from-literal=airbyte-password="$AIRBYTE_PG_PASSWORD"
   ```

   **DuckDB Quack token** ([D-033](docs/decisions/033-duckdb-service-configuration.md)): if `.env` has
   no `QUACK_TOKEN` yet, generate it the same way and load `.env` again, then send it with the
   Postgres password:

   ```bash
   echo "QUACK_TOKEN=$(openssl rand -hex 16)" >> .env
   ```

   ```bash
   kubectl create namespace duckdb
   ```

   ```bash
   kubectl -n duckdb create secret generic duckdb-credentials --from-literal=quack-token="$QUACK_TOKEN" --from-literal=postgres-password="$POSTGRES_PASSWORD"
   ```

2. **Argo CD:** apply the `infra/aws/gitops` root after the cluster
   ([01.04 design](specs/01-ingestion-airbyte-s3/04-argo-cd/spec.md#design)):

   ```bash
   terraform -chdir=infra/aws/gitops init
   ```

   ```bash
   terraform -chdir=infra/aws/gitops plan -out=tfplan
   ```

   ```bash
   terraform -chdir=infra/aws/gitops apply tfplan
   ```

3. **Airbyte, Postgres, DuckDB and the StorageClass:** they are manifests in `platform/aws`; Argo CD
   applies them after `git push` to `main` ([01.05 design](specs/01-ingestion-airbyte-s3/05-airbyte/spec.md#design)).
4. **Check:** `kubectl -n argocd get applications` shows `platform`, `airbyte`, `postgres` and
   `duckdb` `Synced` and `Healthy`, or open the [Argo CD UI](#43-argo-cd).

### 3.3 Services without Argo CD (manual)

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
   ```

   ```bash
   yq '.spec.source.helm.valuesObject' platform/aws/airbyte.yaml > airbyte-values.yaml
   ```

   ```bash
   helm repo add airbyte https://airbytehq.github.io/charts
   ```

   ```bash
   helm install airbyte airbyte/airbyte --version "$VERSION" \
     --namespace airbyte --create-namespace --values airbyte-values.yaml --wait --timeout 15m
   ```

   ```bash
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

| Service | Open | URL | User | Get the password |
|---|---|---|---|---|
| [AWS console](#41-aws-and-kubernetes) | — | AWS console, region `us-east-1` | Account of the `eks-ws` profile | Your AWS sign-in |
| [Argo CD UI](#43-argo-cd) | `kubectl -n argocd port-forward svc/argocd-server 8080:443` | `https://localhost:8080` | `admin` | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 -d; echo` |
| [Airbyte UI](#44-airbyte) | `kubectl -n airbyte port-forward svc/airbyte-airbyte-server-svc 8001:8001` | `http://localhost:8001` | Your email | `kubectl -n airbyte get secret airbyte-auth-secrets -o jsonpath='{.data.instance-admin-password}' \| base64 -d; echo` |
| [Source Postgres](#45-source-postgres) | `kubectl -n postgres exec -it postgres-0 -- psql -U postgres -d source` | — | `postgres` | `POSTGRES_PASSWORD` in `.env`, or `kubectl -n postgres get secret postgres-credentials -o jsonpath='{.data.password}' \| base64 -d; echo` |
| [Source Postgres for Airbyte](#45-source-postgres) | Host `postgres.postgres.svc.cluster.local`, port `5432`, database `source` | — | `airbyte` | `AIRBYTE_PG_PASSWORD` in `.env`, or `kubectl -n postgres get secret postgres-credentials -o jsonpath='{.data.airbyte-password}' \| base64 -d; echo` |
| [DuckDB UI](#46-duckdb-ui) | `while true; do kubectl -n duckdb port-forward deploy/duckdb 4213:4213; sleep 1; done` | `http://localhost:4213` | — | None. Quack token (local UI only): `QUACK_TOKEN` in `.env`, or `kubectl -n duckdb get secret duckdb-credentials -o jsonpath='{.data.quack-token}' \| base64 -d; echo` |

### 4.1 AWS and Kubernetes

- **AWS console:** sign in to the account of the `eks-ws` profile and select region `us-east-1`.
  Never write credentials here.
- **Kubernetes:** `aws eks update-kubeconfig --name eks-for-data --region us-east-1`. The EKS API only
  accepts your current public IP; if it changed, re-apply `infra/aws/cluster` (Terraform detects the
  new IP).

### 4.2 Port-Forwards

Run each port-forward below in its own Git Bash terminal and leave it open while you use the UI.
Lines like `Handling connection for 8080` are harmless.

- **Stop it:** `Ctrl+C` in its terminal.
- **`lost connection to pod`:** run the same command again, then reload the page.

### 4.3 Argo CD

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Open `https://localhost:8080`, accept the self-signed certificate warning, and log in with user
`admin` and the password printed above.

### 4.4 Airbyte

```bash
kubectl -n airbyte get secret airbyte-auth-secrets -o jsonpath='{.data.instance-admin-password}' | base64 -d; echo
```

```bash
kubectl -n airbyte port-forward svc/airbyte-airbyte-server-svc 8001:8001
```

Open `http://localhost:8001`, enter your email, and sign in with the password printed above.

### 4.5 Source Postgres

`psql` inside the Postgres pod; nothing to install:

```bash
kubectl -n postgres exec -it postgres-0 -- psql -U postgres -d source
```

The password is `POSTGRES_PASSWORD` in `.env`. To read it back from the cluster:

```bash
kubectl -n postgres get secret postgres-credentials -o jsonpath='{.data.password}' | base64 -d; echo
```

Airbyte connects as `airbyte` (read-only on every schema, plus `REPLICATION` for CDC,
[D-036](docs/decisions/036-airbyte-database-user.md)) to host `postgres.postgres.svc.cluster.local`,
port `5432`, database `source`. Its password is `AIRBYTE_PG_PASSWORD` in `.env`, or:

```bash
kubectl -n postgres get secret postgres-credentials -o jsonpath='{.data.airbyte-password}' | base64 -d; echo
```

### 4.6 DuckDB UI

**Inside the DuckDB pod** (main path, [D-033](docs/decisions/033-duckdb-service-configuration.md)):
nothing to install; the source Postgres is already attached as `source` and the bronze bucket is
readable. Use it to explore; the pipeline scripts run with the DuckDB CLI
([D-043](docs/decisions/043-pipeline-script-execution.md)).

```bash
while true; do kubectl -n duckdb port-forward deploy/duckdb 4213:4213; sleep 1; done
```

The loop reconnects by itself: the UI often drops the tunnel (`lost connection to pod`); reload the
page after it. Stop it with `Ctrl+C` twice. Lines like `Error creating error stream ... Timeout
occurred` are harmless while the UI keeps working.

Open `http://localhost:4213`. The local port must be 4213: the UI accepts only requests from
`http://localhost:4213`, and any other port fails with "Offset is outside the bounds of the
DataView" (reload with Ctrl+Shift+R after fixing it).

**On your computer** (alternative, not verified): install the
[DuckDB 2.0 CLI](https://duckdb.org/install/), forward the Quack port, and start the UI:

```bash
kubectl -n duckdb port-forward svc/duckdb 9494:9494
```

```bash
duckdb -ui
```

In the UI, attach the server with `QUACK_TOKEN` from `.env`, or read it back from the cluster:

```bash
kubectl -n duckdb get secret duckdb-credentials -o jsonpath='{.data.quack-token}' | base64 -d; echo
```

`localhost` uses plain HTTP, and AWS queries such as `glob('s3://...')` run on your computer, not on the server:

```sql
CREATE SECRET (TYPE quack, TOKEN '<QUACK_TOKEN>');
ATTACH 'quack:localhost:9494' AS remote;
```

## 5. Teardown

### 5.1 Turn Off

Delete the services **while the cluster is up**, so their EBS volumes are deleted with them; then
destroy the infrastructure. In Git Bash, from the repository root:

**With Argo CD:**

```bash
set -a; source .env; set +a
kubectl delete pod --all                     # no test pods keeping nodes alive
kubectl delete application platform -n argocd   # waits for the cascade to its child applications
kubectl delete namespace airbyte --ignore-not-found   # PVC → Airbyte EBS volume deleted
terraform -chdir=infra/aws/gitops destroy    # Argo CD; asks for "yes"
terraform -chdir=infra/aws/cluster destroy   # shows the plan and asks for "yes"
```

**Without Argo CD:** remove what you installed by hand, then destroy only the `cluster` root:

```bash
helm uninstall airbyte --namespace airbyte
kubectl delete namespace airbyte   # PVC → EBS volume deleted
kubectl delete -f platform/aws/storageclass.yaml
terraform -chdir=infra/aws/cluster destroy
```

The order matters: Argo CD must delete its applications before it is removed, the namespaces with
volumes must go while the cluster is up (otherwise their EBS volumes are left behind and keep
costing), and the `gitops` root needs the cluster to exist. It takes about 10–15 minutes, mostly
deleting the cluster and the NAT Gateways.

| Removed | Cost that stops |
|---|---|
| EKS cluster, Auto Mode nodes, IAM roles, OIDC provider, security groups, CloudWatch log group | US$ 0.10/h + nodes |
| 2 NAT Gateways, 2 Elastic IPs | US$ 0.10/h |
| VPC, subnets, route tables, Internet Gateway, S3 endpoint | (free) |
| Bronze, silver and Airbyte buckets, emptied first (**bronze and silver data is lost**); IAM roles and policies (Airbyte, DuckDB, Spark, Polaris, silver data) | Cents (S3 storage) |
| Argo CD, Airbyte, Postgres, DuckDB and their EBS volumes | Extra Auto Mode node(s) + volumes |

What stays, at no cost:

- The code and `.terraform.lock.hcl` in Git.
- The local `terraform.tfstate`, now empty; the next `apply` recreates everything from it
  ([3. Bring Up](#3-bring-up)).
- The `eks-for-data` context in `~/.kube/config`, pointing to a cluster that no longer exists.
  Remove it with `kubectl config delete-context eks-for-data`.
- The `aws:eks:cluster-name` cost allocation tag activation in Billing.
- Your `.env`, with the passwords used by the next environment.

### 5.2 Check Nothing Is Left

```bash
P="--profile eks-ws --region us-east-1 --output text"
aws eks list-clusters $P
aws ec2 describe-nat-gateways $P --query 'NatGateways[?State!=`deleted`].NatGatewayId'
aws ec2 describe-addresses $P --query 'Addresses[].PublicIp'
aws ec2 describe-vpcs --filters Name=tag:project,Values=2026_eks_for_data $P --query 'Vpcs[].VpcId'
```

- Expected result: every command returns empty (NAT Gateways may show `deleting` for a few minutes).
- EKS may recreate the `/aws/eks/eks-for-data/cluster` log group right after the destroy with
  in-flight logs. It costs cents, but the next `apply` fails because the log group already exists.
  Check with `MSYS_NO_PATHCONV=1 aws logs describe-log-groups --log-group-name-prefix /aws/eks/eks-for-data $P`
  and, if it is there, delete it with
  `MSYS_NO_PATHCONV=1 aws logs delete-log-group --log-group-name /aws/eks/eks-for-data/cluster --profile eks-ws --region us-east-1`.
