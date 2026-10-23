# 01 — Ingestion: Airbyte Writing Parquet to S3: How to Verify

An EKS cluster running Airbyte reads a public API and writes Parquet files to the S3 bronze bucket,
all deployed with Terraform and Argo CD. Each step below is verified on its own; the end-to-end
verification proves the phase [Done When](plan.md#done-when).

## Prerequisites

- AWS account access through the `eks-ws` profile (see `.env`)
- AWS console access to the same account, region `us-east-1`
- Git Bash with the `.env` variables loaded: `set -a; source .env; set +a`
- kubectl 1.35 to 1.37 (`kubectl version --client`)

## Access

- **AWS console:** sign in to the account of the `eks-ws` profile and select region `us-east-1`.
  Never write credentials here.
- **Kubernetes:** `aws eks update-kubeconfig --name eks-for-data --region us-east-1`. The EKS API only
  accepts your current public IP; if it changed, re-apply `infra/aws/cluster` with
  `export TF_VAR_operator_cidr="$(curl -s https://checkip.amazonaws.com)/32"`.

## Step Verification

### 01.01 — Network

1. Open the AWS console → **VPC** → **Your VPCs** → select `eks-for-data-vpc` → **Resource map** tab.
   - Expected result: 2 Availability Zones (`us-east-1a`, `us-east-1b`), 2 public and 2 private
     subnets, 1 Internet Gateway, 2 NAT Gateways and the S3 endpoint.
2. In the same map, follow each private route table (`eks-for-data-vpc-private-us-east-1a` and
   `-1b`).
   - Expected result: each one goes to the NAT Gateway of its own AZ and to the S3 endpoint.

### 01.02 — EKS Cluster

1. Open the AWS console → **EKS** → **Clusters** → `eks-for-data`.
   - Expected result: status `Active`, Kubernetes version `1.36`, **EKS Auto Mode** enabled.
2. Run a pod and read its output:
   ```bash
   kubectl run hello --image=public.ecr.aws/docker/library/busybox:1.37 --restart=Never -- sh -c 'echo hello; sleep 120'
   kubectl wait --for=condition=Ready pod/hello --timeout=180s
   kubectl logs hello
   kubectl delete pod hello
   ```
   - Expected result: `hello`. Auto Mode creates a node for the pod and removes it once empty;
     `sleep 120` keeps the pod, and so the node, alive while you read the log.
   - If `kubectl logs` returns `tls: internal error`, the new node does not have its kubelet
     certificate yet (about 20 seconds after the pod starts): wait 30 seconds and run it again.
3. Open **Billing and Cost Management** → **Cost allocation tags**; activate `aws:eks:cluster-name`
   (AWS-generated tags) and `project` (user-defined tags).
   - Expected result: both `Active`. New tags can take up to 24 hours to appear in the list.

### 01.03 — Data Storage and Access

1. Open the AWS console → **S3** → `eks-for-data-bronze-<account_id>` → **Permissions** tab, then
   **Properties** tab. Repeat for `eks-for-data-airbyte-<account_id>`.
   - Expected result: **Block all public access: On**; **Default encryption: SSE-S3**;
     **Bucket Versioning: Disabled**.
2. Write a file to the bronze bucket from a pod, as Airbyte will, using the `eks-for-data-airbyte`
   role (IRSA):
   ```bash
   ROLE=$(terraform -chdir=infra/aws/cluster output -raw airbyte_role_arn)
   BUCKET=$(terraform -chdir=infra/aws/cluster output -raw bronze_bucket)
   kubectl create namespace airbyte
   kubectl -n airbyte create serviceaccount airbyte-admin
   kubectl -n airbyte annotate serviceaccount airbyte-admin eks.amazonaws.com/role-arn=$ROLE
   kubectl -n airbyte run hello-s3 --image=public.ecr.aws/aws-cli/aws-cli:2.38.1 --restart=Never \
     --overrides='{"spec":{"serviceAccountName":"airbyte-admin"}}' \
     --command -- bash -c "echo hello | aws s3 cp - s3://$BUCKET/test/hello.txt && echo uploaded; sleep 120"
   kubectl -n airbyte wait --for=condition=Ready pod/hello-s3 --timeout=180s
   kubectl -n airbyte logs hello-s3
   ```
   - Expected result: the log shows `uploaded`, and the console shows `hello.txt` under `test/` in
     the bronze bucket. `sleep 120` keeps the pod, and so the node, alive while you read the log.
   - If `kubectl logs` returns `tls: internal error` or shows nothing yet, the node or the upload
     is still starting: wait 30 seconds and run it again.
3. Clean up:
   ```bash
   aws s3 rm s3://$BUCKET/test/hello.txt
   kubectl delete namespace airbyte
   ```
   - Expected result: the file and the namespace are gone.

### 01.04 — Argo CD

1. Get the `admin` password and open the UI by port-forward, in the background (`&`) so the
   terminal stays free:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
   kubectl -n argocd port-forward svc/argocd-server 8080:443 &
   ```
   - Expected result: a password printed, then `Forwarding from 127.0.0.1:8080 -> 8080`. Lines like
     `Handling connection for 8080` may appear while you type; they are harmless.
   - `jobs` lists the background processes of this terminal, e.g. `[1]+ Running kubectl ... &`;
     the number in brackets identifies each one.
2. Open `https://localhost:8080`, accept the self-signed certificate warning, and log in with user
   `admin` and the password from step 1.
   - Expected result: the **Applications** page shows `platform`, **Synced** and **Healthy**.
3. Open `platform` → **App Details**.
   - Expected result: repository `https://github.com/AndreRosaLopes/2026_eks_for_data.git`,
     revision `main`, path `platform/aws`; **Sync Policy** automated, with prune and self heal.
4. Stop the port-forward, from the same terminal:
   ```bash
   jobs        # find the port-forward number, e.g. [1]
   kill %1     # use that number
   ```
   - Expected result: `jobs` no longer lists it, and `https://localhost:8080` stops loading.

### 01.05 — Airbyte

1. Open the Argo CD UI (01.04, steps 1–2) → application `airbyte`.
   - Expected result: **Synced** and **Healthy**; the resource tree shows the Airbyte pods
     (server, worker, workload-launcher, workload-api-server, temporal, cron, manifest-server,
     `airbyte-db`).
2. Get the Airbyte password and open the UI by port-forward, in the background:
   ```bash
   kubectl -n airbyte get secret airbyte-auth-secrets -o jsonpath='{.data.instance-admin-password}' | base64 -d; echo
   kubectl -n airbyte port-forward svc/airbyte-airbyte-server-svc 8001:8001 &
   ```
   - Expected result: a password printed, then `Forwarding from 127.0.0.1:8001 -> 8001`.
3. Open `http://localhost:8001`, enter your email, and sign in with the password from step 2.
   - Expected result: the Airbyte home page.
4. Stop the port-forwards (Airbyte and, if open, Argo CD): `jobs`, then `kill %N` for each one.
   - Expected result: `jobs` lists nothing.

## End-to-End Verification

Written on the last step: walkthrough proving the phase "Done When".

## Teardown

The environment has two Terraform roots (`infra/aws/cluster` and `infra/aws/gitops`) plus what Argo
CD deploys, removed in the order below. Each step's own teardown is in its spec (links below).

### Turn Off

In Git Bash, from the repository root:

```bash
set -a; source .env; set +a
export TF_VAR_operator_cidr="$(curl -s https://checkip.amazonaws.com)/32"   # required variable
kubectl delete pod --all                     # no test pods keeping nodes alive
kubectl delete application platform -n argocd   # waits for the cascade to its child applications
kubectl delete namespace airbyte --ignore-not-found   # PVC → Airbyte EBS volume deleted
terraform -chdir=infra/aws/gitops destroy    # Argo CD; asks for "yes"
terraform -chdir=infra/aws/cluster destroy   # shows the plan and asks for "yes"
```

The order matters: Argo CD must delete its applications before it is removed, the `airbyte`
namespace must go while the cluster is up (otherwise its EBS volume is left behind and keeps
costing), and the `gitops` root needs the cluster to exist. It takes about 10–15 minutes, mostly deleting the cluster and the NAT
Gateways.

| Removed | Cost that stops |
|---|---|
| EKS cluster, Auto Mode nodes, IAM roles, OIDC provider, security groups, CloudWatch log group | US$ 0.10/h + nodes |
| 2 NAT Gateways, 2 Elastic IPs | US$ 0.10/h |
| VPC, subnets, route tables, Internet Gateway, S3 endpoint | (free) |
| Bronze and Airbyte buckets, emptied first (**bronze data is lost**); Airbyte IAM role and policy | Cents (S3 storage) |
| Argo CD, Airbyte and the Airbyte EBS volume (1 GiB gp3) | Extra Auto Mode node(s) + ~US$ 0.08/month |

What stays, at no cost:

- The code and `.terraform.lock.hcl` in Git.
- The local `terraform.tfstate`, now empty; the next `apply` recreates everything from it.
- The `eks-for-data` context in `~/.kube/config`, pointing to a cluster that no longer exists.
  Remove it with `kubectl config delete-context eks-for-data`.
- The `aws:eks:cluster-name` cost allocation tag activation in Billing.

### Check Nothing Is Left

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

### Turn On Again

```bash
set -a; source .env; set +a
export TF_VAR_operator_cidr="$(curl -s https://checkip.amazonaws.com)/32"
terraform -chdir=infra/aws/cluster plan -out=tfplan
terraform -chdir=infra/aws/cluster apply tfplan
aws eks update-kubeconfig --name eks-for-data --region us-east-1
terraform -chdir=infra/aws/gitops plan -out=tfplan
terraform -chdir=infra/aws/gitops apply tfplan
```

It takes about 20–25 minutes and recreates the same environment (resource IDs change). Argo CD then
deploys what is in `platform/aws` on `main`.

### Step Teardowns

- [01.01 — Network](01-network/spec.md#teardown)
- [01.02 — EKS Cluster](02-eks-cluster/spec.md#teardown)
- [01.03 — Data Storage and Access](03-data-storage/spec.md#teardown)
- [01.04 — Argo CD](04-argo-cd/spec.md#teardown)
- [01.05 — Airbyte](05-airbyte/spec.md#teardown)
