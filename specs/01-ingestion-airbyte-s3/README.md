# 01 — Ingestion: Airbyte Writing Parquet to S3: How to Verify

An EKS cluster running Airbyte reads a public API and writes Parquet files to the S3 bronze bucket,
all deployed with Terraform and Argo CD. Each step below is verified on its own; the end-to-end
verification proves the phase [Done When](plan.md#done-when).

## Prerequisites

- AWS account access through the `eks-ws` profile (see `.env`)
- AWS console access to the same account, region `us-east-1`

## Access

- **AWS console:** sign in to the account of the `eks-ws` profile and select region `us-east-1`.
  Never write credentials here.

## Step Verification

### 01.01 — Network

1. Open the AWS console → **VPC** → **Your VPCs** → select `eks-for-data-vpc` → **Resource map** tab.
   - Expected result: 2 Availability Zones (`us-east-1a`, `us-east-1b`), 2 public and 2 private
     subnets, 1 Internet Gateway, 2 NAT Gateways and the S3 endpoint.
2. In the same map, follow each private route table (`eks-for-data-vpc-private-us-east-1a` and
   `-1b`).
   - Expected result: each one goes to the NAT Gateway of its own AZ and to the S3 endpoint.

## End-to-End Verification

Written on the last step: walkthrough proving the phase "Done When".

## Teardown

- [01.01 — Network](01-network/spec.md#teardown)
