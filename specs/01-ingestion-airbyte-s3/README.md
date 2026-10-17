# 01 — Ingestion: Airbyte Writing Parquet to S3: How to Verify

An EKS cluster running Airbyte reads a public API and writes Parquet files to the S3 bronze bucket,
all deployed with Terraform and Argo CD. Each step below is verified on its own; the end-to-end
verification proves the phase [Done When](plan.md#done-when).

## Prerequisites

- AWS account access through the `eks-ws` profile (see `.env`)
- AWS console access to the same account, region `us-east-1`
- Git Bash with the `.env` variables loaded: `set -a; source .env; set +a`
- kubectl 1.36 to 1.38 (`kubectl version --client`)

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
   - Expected result: status `Active`, Kubernetes version `1.37`, **EKS Auto Mode** enabled.
2. Run a pod and read its output:
   ```bash
   kubectl run hello --image=public.ecr.aws/docker/library/busybox:1.37 --restart=Never -- echo hello
   kubectl logs hello      # wait a minute if the pod is still starting
   kubectl delete pod hello
   ```
   - Expected result: `hello`. Auto Mode creates a node for the pod and removes it once empty.
3. Open **Billing and Cost Management** → **Cost allocation tags**; activate `aws:eks:cluster-name`
   (AWS-generated tags) and `project` (user-defined tags).
   - Expected result: both `Active`. New tags can take up to 24 hours to appear in the list.

## End-to-End Verification

Written on the last step: walkthrough proving the phase "Done When".

## Teardown

- [01.01 — Network](01-network/spec.md#teardown)
- [01.02 — EKS Cluster](02-eks-cluster/spec.md#teardown)
