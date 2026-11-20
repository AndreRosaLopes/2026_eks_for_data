# How to Run

The home page for operating the platform: one flow that brings the environment up, gets it ready
for the [labs](docs/labs/README.md), and takes it down. Every service is a manifest in
`platform/aws`, applied by Argo CD from Git ([D-007](docs/decisions/007-argo-cd-installation.md)).
Installing the services by hand, without Argo CD, is
[Lab 1.01](docs/labs/lab_infrastructure_1.01.md).

## 1. Phases

Each phase has its own **Run** page (what to execute) and **Verify** page (the checks and expected
results).

| Phase | Status | Run | Verify |
|---|---|---|---|
| 01 — Ingestion: Airbyte writing Parquet to S3 | Done | [Run](specs/01-ingestion-airbyte-s3/HOW_TO_RUN.md) | [Verify](specs/01-ingestion-airbyte-s3/README.md) |
| 02 — Transactional ingestion: TPC-H in Postgres, cursor and CDC | In progress (02.01–02.09 done) | [Run](specs/02-transactional-ingestion/HOW_TO_RUN.md) | [Verify](specs/02-transactional-ingestion/README.md) |
| 03 — Processing: Spark and Iceberg | In progress (03.01 to 03.05 done) | [Run](specs/03-processing-spark-iceberg/HOW_TO_RUN.md) | [Verify](specs/03-processing-spark-iceberg/README.md) |
| 04 — Orchestration: Airflow for Airbyte and Spark | In progress (04.01 to 04.03 done) | [Run](specs/04-orchestration-airflow/HOW_TO_RUN.md) | [Verify](specs/04-orchestration-airflow/README.md) |
| 05 — Lab state: Velero keeps the databases and buckets between environments | Done | [Run](specs/05-lab-state-persistence/HOW_TO_RUN.md) | [Verify](specs/05-lab-state-persistence/README.md) |

## 2. Prerequisites

- AWS account access through the `eks-ws` profile (see `.env`)
- AWS console access to the same account, region `us-east-1`
- Git Bash in the repository root, with the `.env` variables loaded (Bash syntax; it does not work
  in PowerShell): `set -a; source .env; set +a`
- kubectl 1.35 to 1.37 (`kubectl version --client`)
- [Velero CLI](https://velero.io/docs/main/basic-install/) 1.18.2, the server's version
  ([D-081](docs/decisions/081-velero-version.md)): `velero version --client-only`. On Windows,
  `choco install velero`, or the release archive from GitHub
- Python 3.10 to 3.14 and the Polaris CLI
  ([D-060](docs/decisions/060-polaris-catalog-creation.md)): `pip install apache-polaris==1.8.0`

## 3. Flow

### 3.1 Bring Up

In Git Bash, from the repository root (cost starts running):

```bash
./scripts/up.sh
```

The same command serves both cases, and it detects which one applies:

- **First time:** the Velero bucket has no backup (first bring-up, or after a
  [purge](#37-purge-full-reset)). The databases start empty.
- **Continue:** the backup left by the last [Turn Off](#35-turn-off) exists. The databases come back
  as they were.

What it does, in order, with no `yes` prompt (each step by hand:
[Appendix A.1](#a1-bring-up-by-hand)):

| # | Step | First time | Continue |
|---|---|---|---|
| 1 | Passwords and keys in `.env` | Generated | Reused; only missing ones are generated |
| 2 | AWS account check | Stops if it is not `ACCOUNT_ID` from `.env` | Same |
| 3 | Buckets: `infra/aws/data`, kept between environments ([D-077](docs/decisions/077-persistent-data-root.md)) | Created | No changes |
| 4 | Network, EKS cluster, IAM roles: `infra/aws/cluster` (about 15–20 minutes); the EKS API accepts only your public IP | Created | Created |
| 5 | Velero: `infra/aws/backup`, before Argo CD starts any database ([D-078](docs/decisions/078-velero-installation-and-restore-order.md)) | Installed | Installed |
| 6 | `kubectl` pointed to the cluster | Same | Same |
| 7 | Namespaces and Secrets from `.env`: `postgres`, `duckdb`, `polaris`, `airflow` | Created | Created |
| 8 | Restore the database volumes from the latest backup ([05.04 design](specs/05-lab-state-persistence/04-backup-restore/spec.md#design)) | Skipped: `No backup in ...` | Restored; must end `Completed` |
| 9 | Argo CD: `infra/aws/gitops`; it then deploys every manifest in `platform/aws` from `main` ([01.05 design](specs/01-ingestion-airbyte-s3/05-airbyte/spec.md#design)) | Installed | Installed |
| 10 | Polaris realm bootstrap, once `polaris-postgres` and `polaris` are Healthy ([D-059](docs/decisions/059-polaris-realm-bootstrap.md)) | Realm created | Unchanged: it is in the restored database |

Changes to `platform/aws` reach the cluster only after `git push` to `main`. What the infrastructure
creates and why: [01.01 design](specs/01-ingestion-airbyte-s3/01-network/spec.md#design),
[01.02 design](specs/01-ingestion-airbyte-s3/02-eks-cluster/spec.md#design),
[01.03 design](specs/01-ingestion-airbyte-s3/03-data-storage/spec.md#design).

### 3.2 Check

```bash
kubectl -n argocd get applications
```

Expected result: `platform`, `airbyte`, `postgres`, `duckdb`, `spark-operator`, `spark-jobs`,
`polaris-postgres`, `polaris`, `airflow-postgres` and `airflow` all `Synced` and `Healthy`. The same
view is in the [Argo CD UI](#43-argo-cd).

### 3.3 Polaris Engine Access

Spark and DuckDB reach the Iceberg catalog with one Polaris principal (an account with its own
client ID and secret) that has full content rights on the lab catalog
([D-062](docs/decisions/062-polaris-engine-credentials.md)). The catalog keeps its tables in the
silver bucket, and Polaris vends their credentials by assuming the silver data role
([D-049](docs/decisions/049-silver-storage-credentials.md)). The catalog and the principal live in
the catalog Postgres, which [3.1](#31-bring-up) step 8 restores:

- **Continue:** the catalog, the principal and the `POLARIS_CLIENT_ID` and `POLARIS_CLIENT_SECRET`
  lines in `.env` are still valid. Run only step 7.
- **First time:** run every step. The principal's credentials are the `POLARIS_CLIENT_ID` and
  `POLARIS_CLIENT_SECRET` lines in `.env`, generated once and kept: step 5 loads them into Polaris.

You choose the catalog name; the commands use `<catalog>`. The names `engines`, `engine_role` and
`<catalog>_contributor` are examples: the principal, its roles and their privileges are lab
choices.

1. Load `.env`:

   ```bash
   set -a; source .env; set +a
   ```

2. In another terminal, forward the Polaris port ([4.7 Polaris](#47-polaris)):

   ```bash
   kubectl -n polaris port-forward svc/polaris 8181:8181
   ```

3. Create the catalog, with its base location inside the silver bucket:

   ```bash
   polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" catalogs create --storage-type s3 --default-base-location s3://eks-for-data-silver-283429977024/<catalog> --role-arn arn:aws:iam::283429977024:role/eks-for-data-silver-data --region us-east-1 <catalog>
   ```

4. List the catalogs:

   ```bash
   polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" catalogs list
   ```

5. Create the principal with the credentials in `.env`. First add them to `.env` if they are
   missing (each command keeps an existing value):

   ```bash
   grep -q "^POLARIS_CLIENT_ID=." .env || echo "POLARIS_CLIENT_ID=$(openssl rand -hex 8)" >> .env
   ```

   ```bash
   grep -q "^POLARIS_CLIENT_SECRET=." .env || echo "POLARIS_CLIENT_SECRET=$(openssl rand -hex 16)" >> .env
   ```

   ```bash
   set -a; source .env; set +a
   ```

   Create the principal, discarding the random credentials Polaris generates, then replace them
   with the ones in `.env` (root only; the reset is on by default, `ENABLE_CREDENTIAL_RESET`):

   ```bash
   polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" principals create engines > /dev/null
   ```

   ```bash
   polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" principals reset engines --new-client-id "$POLARIS_CLIENT_ID" --new-client-secret "$POLARIS_CLIENT_SECRET"
   ```

   Expected result: the output shows `clientId` equal to `POLARIS_CLIENT_ID` in `.env`.

6. Create the roles, connect them (principal → principal role → catalog role) and grant the
   privilege on the catalog:

   ```bash
   polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" principal-roles create engine_role
   ```

   ```bash
   polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" principal-roles grant --principal engines engine_role
   ```

   ```bash
   polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" catalog-roles create --catalog <catalog> <catalog>_contributor
   ```

   ```bash
   polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" catalog-roles grant --catalog <catalog> --principal-role engine_role <catalog>_contributor
   ```

   ```bash
   polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" privileges catalog grant --catalog <catalog> --catalog-role <catalog>_contributor CATALOG_MANAGE_CONTENT
   ```

7. Send the credentials to Spark and DuckDB as Secret `polaris-credentials`
   ([D-031](docs/decisions/031-source-postgres-password-from-env.md)), then restart DuckDB so it
   reads them:

   ```bash
   kubectl -n spark create secret generic polaris-credentials --from-literal=POLARIS_CLIENT_ID="$POLARIS_CLIENT_ID" --from-literal=POLARIS_CLIENT_SECRET="$POLARIS_CLIENT_SECRET"
   ```

   ```bash
   kubectl -n duckdb create secret generic polaris-credentials --from-literal=POLARIS_CLIENT_ID="$POLARIS_CLIENT_ID" --from-literal=POLARIS_CLIENT_SECRET="$POLARIS_CLIENT_SECRET"
   ```

   ```bash
   kubectl -n duckdb rollout restart deploy/duckdb
   ```

### 3.4 Do the Labs

The environment is ready. Follow the [labs](docs/labs/README.md) and the phase Run pages
([1. Phases](#1-phases)); the services are reached as in [4. Access](#4-access).

### 3.5 Turn Off

Back up the databases and destroy the infrastructure, so the next [Bring Up](#31-bring-up)
continues from this point ([05.04 design](specs/05-lab-state-persistence/04-backup-restore/spec.md#design)).
In Git Bash, from the repository root (about 10–15 minutes, mostly deleting the cluster and the NAT
Gateways):

```bash
./scripts/down.sh
```

What it does, in order, with no `yes` prompt (each step by hand:
[Appendix A.2](#a2-turn-off-by-hand)):

| # | Step |
|---|---|
| 1 | AWS account check; `kubectl` pointed to the cluster |
| 2 | Stop the services: delete every pod in `default`, the `platform` application (Argo CD deletes the others; database volumes stay) and the `airbyte-db` StatefulSet; re-apply the StorageClass, which Velero needs |
| 3 | Back up the five volumes of the database namespaces (the four databases and the Airflow triggerer logs) with Velero; if the backup does not end `Completed`, it stops there and nothing is deleted |
| 4 | Delete every older backup, with its EBS snapshots |
| 5 | Delete the database namespaces: `postgres`, `polaris`, `airflow`, `airbyte` (their PVCs and EBS volumes go) |
| 6 | Destroy `infra/aws/gitops` (Argo CD), `infra/aws/backup` (Velero) and `infra/aws/cluster` |
| 7 | Delete the EKS log group if EKS recreated it (the next bring-up fails if it exists) |
| 8 | List anything left ([3.6](#36-check-nothing-is-left)) and remove the `kubectl` context |

The order matters: Argo CD must delete its applications before it is removed, the backup must
complete before the database namespaces go, the namespaces with volumes must go while the cluster is
up (otherwise their EBS volumes are left behind and keep costing), and the `gitops` root needs the
cluster to exist.

| Removed | Cost that stops |
|---|---|
| EKS cluster, Auto Mode nodes, IAM roles, OIDC provider, security groups, CloudWatch log group | US$ 0.10/h + nodes |
| 2 NAT Gateways, 2 Elastic IPs | US$ 0.10/h |
| VPC, subnets, route tables, Internet Gateway, S3 endpoint | (free) |
| IAM roles and policies (Airbyte, DuckDB, Spark, Polaris, silver data, Airflow, Velero) | (free) |
| Argo CD, Velero, Airbyte, Postgres, DuckDB, Spark Operator, Polaris, Airflow, the catalog and Airflow Postgres and their EBS volumes | Extra Auto Mode node(s) + volumes |

What stays, at a cost of cents per month, until the [purge](#37-purge-full-reset):

- The five buckets of `infra/aws/data` (bronze, silver, Airbyte, Airflow, Velero), with their data
  (S3 storage).
- The latest backup: its files in the Velero bucket and the EBS snapshots of the five volumes
  (US$ 0.05/GB-month, [D-076](docs/decisions/076-lab-state-persistence.md)).

What stays, at no cost:

- The code and `.terraform.lock.hcl` in Git.
- The local `terraform.tfstate` of each root, empty except for `infra/aws/data`; the next `apply`
  recreates everything from it.
- The `aws:eks:cluster-name` cost allocation tag activation in Billing.
- Your `.env`, with the passwords used by the next environment.

### 3.6 Check Nothing Is Left

`down.sh` runs the first four commands at its end:

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
- Expected result after the purge ([3.7](#37-purge-full-reset)): also no `eks-for-data-*` bucket and
  no EBS snapshot tagged `eks:eks-cluster-name=eks-for-data`:
  `aws s3 ls --profile eks-ws | grep eks-for-data` and
  `aws ec2 describe-snapshots --owner-ids self --filters Name=tag:eks:eks-cluster-name,Values=eks-for-data $P --query 'Snapshots[].SnapshotId'`.

### 3.7 Purge (Full Reset)

Removes everything the lab keeps between environments: every backup with its EBS snapshots, and the
five buckets with their data. The next [Bring Up](#31-bring-up) is a first time
([D-088](docs/decisions/088-purge-backup-deletion.md)). It needs the cluster up, because Velero
deletes the snapshots; if the environment is down, bring it up first.

```bash
./scripts/down.sh --purge
```

It runs [3.5](#35-turn-off) with steps 3 and 4 replaced by deleting every backup, and ends by
destroying `infra/aws/data` (by hand: [Appendix A.3](#a3-purge-by-hand)).

## 4. Access

| Service | Open | URL | User | Get the password |
|---|---|---|---|---|
| [AWS console](#41-aws-and-kubernetes) | — | AWS console, region `us-east-1` | Account of the `eks-ws` profile | Your AWS sign-in |
| [Argo CD UI](#43-argo-cd) | `kubectl -n argocd port-forward svc/argocd-server 8080:443` | `https://localhost:8080` | `admin` | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 -d; echo` |
| [Airbyte UI](#44-airbyte) | `kubectl -n airbyte port-forward svc/airbyte-airbyte-server-svc 8001:8001` | `http://localhost:8001` | Your email | `kubectl -n airbyte get secret airbyte-auth-secrets -o jsonpath='{.data.instance-admin-password}' \| base64 -d; echo` |
| [Source Postgres](#45-source-postgres) | `kubectl -n postgres exec -it postgres-0 -- psql -U postgres -d source` | — | `postgres` | `POSTGRES_PASSWORD` in `.env`, or `kubectl -n postgres get secret postgres-credentials -o jsonpath='{.data.password}' \| base64 -d; echo` |
| [Source Postgres for Airbyte](#45-source-postgres) | Host `postgres.postgres.svc.cluster.local`, port `5432`, database `source` | — | `airbyte` | `AIRBYTE_PG_PASSWORD` in `.env`, or `kubectl -n postgres get secret postgres-credentials -o jsonpath='{.data.airbyte-password}' \| base64 -d; echo` |
| [DuckDB UI](#46-duckdb-ui) | `while true; do kubectl -n duckdb port-forward deploy/duckdb 4213:4213; sleep 1; done` | `http://localhost:4213` | — | None. Quack token (local UI only): `QUACK_TOKEN` in `.env`, or `kubectl -n duckdb get secret duckdb-credentials -o jsonpath='{.data.quack-token}' \| base64 -d; echo` |
| [Polaris API](#47-polaris) | `kubectl -n polaris port-forward svc/polaris 8181:8181` | `http://localhost:8181` (Polaris CLI) | Client ID `root` | `POLARIS_ROOT_SECRET` in `.env` |
| [Airflow UI](#48-airflow) | `kubectl -n airflow port-forward svc/airflow-api-server 8080:8080` | `http://localhost:8080` | `admin` | `AIRFLOW_ADMIN_PASSWORD` in `.env` |
| [Catalog Postgres](#47-polaris) | `kubectl -n polaris exec -it polaris-postgres-0 -- psql -U postgres -d polaris` | — | `postgres` (or `polaris`) | `POLARIS_POSTGRES_PASSWORD` (or `POLARIS_PG_PASSWORD`) in `.env` |

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

### 4.7 Polaris

Polaris has no UI; it is used through the Polaris CLI ([2. Prerequisites](#2-prerequisites)) with
the root credentials, in realm `POLARIS`. Forward its port in its own terminal
([4.2 Port-Forwards](#42-port-forwards)):

```bash
kubectl -n polaris port-forward svc/polaris 8181:8181
```

The CLI reaches `localhost:8181` by default. The root client ID is `root`; the secret is
`POLARIS_ROOT_SECRET` in `.env` (load it with `set -a; source .env; set +a`).

### 4.8 Airflow

The Airflow UI and REST API are served by the API server
([D-071](docs/decisions/071-airflow-admin-login.md)). Forward its port in its own terminal
([4.2 Port-Forwards](#42-port-forwards)):

```bash
kubectl -n airflow port-forward svc/airflow-api-server 8080:8080
```

Open `http://localhost:8080` and sign in as `admin` with `AIRFLOW_ADMIN_PASSWORD` from `.env`. Task
logs are read from the S3 bucket `eks-for-data-airflow-283429977024`
([D-072](docs/decisions/072-airflow-task-log-location.md)).

## Appendix A. The Scripts by Hand

The commands of `scripts/up.sh` and `scripts/down.sh`, one by one, in the same order. Run them in
Git Bash, from the repository root, in one terminal.

### A.1 Bring Up by Hand

The steps of [3.1](#31-bring-up).

1. **Passwords and keys:** generate the values `.env` does not have yet, then load it. Each is 32
   hexadecimal characters, safe in connection strings
   ([D-031](docs/decisions/031-source-postgres-password-from-env.md)); the Airflow Fernet key is
   base64:

   ```bash
   for v in POSTGRES_PASSWORD AIRBYTE_PG_PASSWORD QUACK_TOKEN POLARIS_POSTGRES_PASSWORD POLARIS_PG_PASSWORD POLARIS_ROOT_SECRET AIRFLOW_POSTGRES_PASSWORD AIRFLOW_PG_PASSWORD AIRFLOW_ADMIN_PASSWORD AIRFLOW_API_SECRET_KEY AIRFLOW_JWT_SECRET; do grep -q "^$v=." .env || echo "$v=$(openssl rand -hex 16)" >> .env; done
   ```

   ```bash
   grep -q '^AIRFLOW_FERNET_KEY=.' .env || echo "AIRFLOW_FERNET_KEY=$(openssl rand -base64 32 | tr '+/' '-_')" >> .env
   ```

   ```bash
   set -a; source .env; set +a
   ```

2. **AWS account:** it must print `283429977024`:

   ```bash
   aws sts get-caller-identity --query Account --output text
   ```

3. **Buckets:** on later bring-ups it reports no changes:

   ```bash
   terraform -chdir=infra/aws/data init
   ```

   ```bash
   terraform -chdir=infra/aws/data apply
   ```

4. **Network, EKS cluster and IAM roles** (about 15–20 minutes):

   ```bash
   terraform -chdir=infra/aws/cluster init
   ```

   ```bash
   terraform -chdir=infra/aws/cluster plan -out=tfplan
   ```

   ```bash
   terraform -chdir=infra/aws/cluster apply tfplan
   ```

5. **Velero:**

   ```bash
   terraform -chdir=infra/aws/backup init
   ```

   ```bash
   terraform -chdir=infra/aws/backup apply
   ```

6. **Point `kubectl` to the cluster:**

   ```bash
   aws eks update-kubeconfig --name eks-for-data --region us-east-1
   ```

7. **Namespaces and Secrets.** Source Postgres, with the `airbyte` user password, which Postgres
   uses on its first start ([D-036](docs/decisions/036-airbyte-database-user.md)):

   ```bash
   kubectl create namespace postgres
   ```

   ```bash
   kubectl -n postgres create secret generic postgres-credentials --from-literal=password="$POSTGRES_PASSWORD" --from-literal=airbyte-password="$AIRBYTE_PG_PASSWORD"
   ```

   DuckDB: the Quack token and the source Postgres password
   ([D-033](docs/decisions/033-duckdb-service-configuration.md)):

   ```bash
   kubectl create namespace duckdb
   ```

   ```bash
   kubectl -n duckdb create secret generic duckdb-credentials --from-literal=quack-token="$QUACK_TOKEN" --from-literal=postgres-password="$POSTGRES_PASSWORD"
   ```

   Polaris: the catalog Postgres superuser and `polaris` user passwords
   ([D-046](docs/decisions/046-catalog-metadata-database.md),
   [D-061](docs/decisions/061-polaris-database-user.md)):

   ```bash
   kubectl create namespace polaris
   ```

   ```bash
   kubectl -n polaris create secret generic polaris-postgres-credentials --from-literal=password="$POLARIS_POSTGRES_PASSWORD" --from-literal=polaris-password="$POLARIS_PG_PASSWORD"
   ```

   ```bash
   kubectl -n polaris create secret generic polaris-persistence --from-literal=username=polaris --from-literal=password="$POLARIS_PG_PASSWORD" --from-literal=jdbcUrl=jdbc:postgresql://polaris-postgres.polaris.svc.cluster.local:5432/polaris
   ```

   Airflow: the metadata Postgres superuser and `airflow` user passwords, the UI `admin` password
   and the three static keys the chart production guide asks for (API secret key, JWT secret,
   Fernet key) ([D-065](docs/decisions/065-airflow-metadata-database.md),
   [D-071](docs/decisions/071-airflow-admin-login.md)):

   ```bash
   kubectl create namespace airflow
   ```

   ```bash
   kubectl -n airflow create secret generic airflow-postgres-credentials --from-literal=password="$AIRFLOW_POSTGRES_PASSWORD" --from-literal=airflow-password="$AIRFLOW_PG_PASSWORD"
   ```

   ```bash
   kubectl -n airflow create secret generic airflow-metadata --from-literal=connection="postgresql://airflow:$AIRFLOW_PG_PASSWORD@airflow-postgres.airflow.svc.cluster.local:5432/airflow"
   ```

   ```bash
   kubectl -n airflow create secret generic airflow-fernet-key --from-literal=fernet-key="$AIRFLOW_FERNET_KEY"
   ```

   ```bash
   kubectl -n airflow create secret generic airflow-api-secret-key --from-literal=api-secret-key="$AIRFLOW_API_SECRET_KEY"
   ```

   ```bash
   kubectl -n airflow create secret generic airflow-jwt-secret --from-literal=jwt-secret="$AIRFLOW_JWT_SECRET"
   ```

   ```bash
   kubectl -n airflow create secret generic airflow-admin --from-literal=password="$AIRFLOW_ADMIN_PASSWORD"
   ```

8. **Restore the databases** (continue only). Velero lists the backups about a minute after it
   starts. If `velero backup get` lists none, skip this step; otherwise restore the one listed,
   replacing `<backup>`:

   ```bash
   velero backup get
   ```

   ```bash
   velero restore create --from-backup <backup> --include-resources persistentvolumeclaims,volumesnapshots.snapshot.storage.k8s.io,volumesnapshotcontents.snapshot.storage.k8s.io --wait
   ```

   The restore must end `Completed`.

9. **Argo CD** ([01.04 design](specs/01-ingestion-airbyte-s3/04-argo-cd/spec.md#design)):

   ```bash
   terraform -chdir=infra/aws/gitops init
   ```

   ```bash
   terraform -chdir=infra/aws/gitops plan -out=tfplan
   ```

   ```bash
   terraform -chdir=infra/aws/gitops apply tfplan
   ```

10. **Polaris realm bootstrap:** creates Polaris's tables in the catalog Postgres and the root
    credentials of realm `POLARIS` with the Polaris admin tool. Run it after Argo CD shows
    `polaris-postgres` and `polaris` **Synced** and **Healthy**. It is safe to run again: a
    bootstrapped realm is left unchanged.

    ```bash
    kubectl -n polaris run polaris-bootstrap --rm -i --restart=Never --image=apache/polaris-admin-tool:1.8.0 --env="polaris.persistence.type=relational-jdbc" --env="quarkus.datasource.username=polaris" --env="quarkus.datasource.password=$POLARIS_PG_PASSWORD" --env="quarkus.datasource.jdbc.url=jdbc:postgresql://polaris-postgres.polaris.svc.cluster.local:5432/polaris" -- bootstrap -r POLARIS -c "POLARIS,root,$POLARIS_ROOT_SECRET"
    ```

### A.2 Turn Off by Hand

The steps of [3.5](#35-turn-off):

```bash
set -a; source .env; set +a
aws sts get-caller-identity --query Account --output text   # must print 283429977024
aws eks update-kubeconfig --name eks-for-data --region us-east-1
kubectl delete pod --all                     # no test pods keeping nodes alive
kubectl delete application platform -n argocd   # waits for the cascade; database volumes stay
kubectl -n airbyte delete statefulset airbyte-db --cascade=foreground --ignore-not-found
kubectl apply -f platform/aws/storageclass.yaml   # the cascade deleted it; Velero needs it
velero backup create lab-$(date -u +%Y%m%d%H%M%S) --include-namespaces postgres,polaris,airflow,airbyte --include-resources persistentvolumeclaims --wait
velero backup get                            # the new backup Completed; delete any older one:
velero backup delete <older-backup> --confirm
kubectl delete namespace postgres polaris airflow airbyte   # PVCs → EBS volumes deleted
terraform -chdir=infra/aws/gitops destroy    # Argo CD; asks for "yes"
terraform -chdir=infra/aws/backup destroy    # Velero; asks for "yes"
terraform -chdir=infra/aws/cluster destroy   # shows the plan and asks for "yes"
```

If the backup does not end `Completed`, stop there: the volumes still exist, and
`velero backup describe <backup>` shows why. Then run [3.6](#36-check-nothing-is-left), and remove
the `kubectl` context of the deleted cluster:

```bash
kubectl config delete-context arn:aws:eks:us-east-1:283429977024:cluster/eks-for-data
```

### A.3 Purge by Hand

Run [A.2](#a2-turn-off-by-hand) with the `velero backup create`, `velero backup get` and
`velero backup delete <older-backup>` lines replaced by:

```bash
velero backup delete --all --confirm
```

Wait until `velero backup get` lists nothing before deleting the namespaces. End with:

```bash
terraform -chdir=infra/aws/data destroy   # empties and deletes the five buckets; asks for "yes"
```
