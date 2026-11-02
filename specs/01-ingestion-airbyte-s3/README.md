[How to Run](../../HOW_TO_RUN.md) › 01 — Ingestion: [Run](HOW_TO_RUN.md) | **Verify**

# 01 — Ingestion: Airbyte Writing Parquet to S3: How to Verify

An EKS cluster running Airbyte reads a public API and writes Parquet files to the S3 bronze bucket,
all deployed with Terraform and Argo CD. Each step below is verified on its own; the end-to-end
verification proves the phase [Done When](plan.md#done-when).

## Prerequisites and Access

- [How to Run, 2. Prerequisites](../../HOW_TO_RUN.md#2-prerequisites)
- [How to Run, 4. Access](../../HOW_TO_RUN.md#4-access): AWS console, Kubernetes, Argo CD and Airbyte

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

1. Open the Argo CD UI and log in ([How to Run, 4.3 Argo CD](../../HOW_TO_RUN.md#43-argo-cd)).
   - Expected result: the **Applications** page shows `platform`, **Synced** and **Healthy**.
2. Open `platform` → **App Details**.
   - Expected result: repository `https://github.com/AndreRosaLopes/2026_eks_for_data.git`,
     revision `main`, path `platform/aws`; **Sync Policy** automated, with prune and self heal.
3. Stop the port-forward ([How to Run, 4.2 Port-Forwards](../../HOW_TO_RUN.md#42-port-forwards)).
   - Expected result: the terminal returns to the prompt, and `https://localhost:8080` stops loading.

### 01.05 — Airbyte

1. Open the Argo CD UI ([How to Run, 4.3 Argo CD](../../HOW_TO_RUN.md#43-argo-cd)) → application
   `airbyte`.
   - Expected result: **Synced** and **Healthy**; the resource tree shows the Airbyte pods
     (server, worker, workload-launcher, workload-api-server, temporal, cron, manifest-server,
     `airbyte-db`).
2. Open the Airbyte UI and sign in ([How to Run, 4.4 Airbyte](../../HOW_TO_RUN.md#44-airbyte)).
   - Expected result: the Airbyte home page.
3. Stop the port-forwards ([How to Run, 4.2 Port-Forwards](../../HOW_TO_RUN.md#42-port-forwards)).
   - Expected result: both terminals return to the prompt.

## End-to-End Verification

Proves the phase [Done When](plan.md#done-when).

1. Bring the environment up: [How to Run, 3. Bring Up](../../HOW_TO_RUN.md#3-bring-up) (skip it if
   the environment is already up).
   - Expected result: `terraform apply` completes for `cluster` and `gitops`; Argo CD shows
     `platform` and `airbyte` **Synced** and **Healthy** (01.04 and 01.05 sections above).
2. Run [Lab 01 — API Ingestion](HOW_TO_RUN.md#1-lab-01--api-ingestion).
   - Expected result: the sync **Succeeded**, and the Parquet file in the bronze bucket is readable,
     with `ditto`.
3. Tear down: [How to Run, 5.1 Turn Off](../../HOW_TO_RUN.md#51-turn-off), then
   [5.2 Check Nothing Is Left](../../HOW_TO_RUN.md#52-check-nothing-is-left).
   - Expected result: every command returns empty; nothing that costs is left.

## Teardown

The whole environment: [How to Run, 5. Teardown](../../HOW_TO_RUN.md#5-teardown). Each step's own
teardown is in its spec:

- [01.01 — Network](01-network/spec.md#teardown)
- [01.02 — EKS Cluster](02-eks-cluster/spec.md#teardown)
- [01.03 — Data Storage and Access](03-data-storage/spec.md#teardown)
- [01.04 — Argo CD](04-argo-cd/spec.md#teardown)
- [01.05 — Airbyte](05-airbyte/spec.md#teardown)
