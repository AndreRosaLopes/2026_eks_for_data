# 01 — Ingestion: Airbyte Writing Parquet to S3: Plan

Status: Approved

## Objective

Deploy, with Terraform and Argo CD only, an EKS cluster running Airbyte that reads a public API
and writes Parquet files to the S3 bronze bucket. It is the foundation the next phases build on.

## Scope

- VPC, EKS cluster, S3 buckets (bronze and Airbyte internal storage) and IAM, in Terraform
- Argo CD, bootstrapped by Terraform
- Airbyte (Helm chart v2), deployed by Argo CD
- Airbyte source, destination (Parquet) and connection: created manually in the Airbyte UI by the
  user, following the phase README, then saved as Terraform code with `import`
- Phase walkthrough and teardown

## Out of Scope

- Trino, dbt, Airflow, silver and gold layers
- Azure and GCP deployments. Known divergences for them: the Airbyte Azure Blob Storage
  destination supports only CSV and JSONL (no Parquet); the GCS destination supports only HMAC keys
- Observability, Ingress, DNS, TLS, CI/CD
- Sync scheduling

## Done When

- Following the walkthrough from an empty account recreates everything with `terraform apply`
  and Argo CD
- Argo CD shows Airbyte `Synced` and `Healthy`
- A sync from the public API to S3 succeeds and readable Parquet files exist in the bronze bucket
- The teardown removes every resource that incurs cost
- No secrets in the repository

## Decisions

- [D-001 — AWS Region](../../docs/decisions/001-aws-region.md)
- [D-002 — Terraform State Backend](../../docs/decisions/002-terraform-state-backend.md)
- [D-003 — Repository and Terraform Root Layout](../../docs/decisions/003-terraform-root-layout.md)
- [D-004 — Terraform Modules](../../docs/decisions/004-terraform-modules.md)
- [D-005 — Network Topology](../../docs/decisions/005-network-topology.md)
- [D-006 — EKS Compute Mode](../../docs/decisions/006-eks-compute-mode.md)
- [D-007 — Argo CD Installation](../../docs/decisions/007-argo-cd-installation.md)
- [D-008 — Pod Identity for AWS Access](../../docs/decisions/008-pod-aws-identity.md)
- [D-009 — Airbyte Internal Storage and Database](../../docs/decisions/009-airbyte-internal-storage.md)
- [D-010 — Airbyte Connection Configuration](../../docs/decisions/010-airbyte-connection-config.md)
- [D-011 — Public API Source](../../docs/decisions/011-public-api-source.md)
- [D-012 — Cluster and UI Access](../../docs/decisions/012-cluster-and-ui-access.md)
- [D-013 — EKS Node Cost Tracking](../../docs/decisions/013-eks-node-cost-tracking.md)
- [D-014 — EKS API Data Encryption](../../docs/decisions/014-eks-api-data-encryption.md)

## Steps

| # | Step | Status |
|---|---|---|
| 01.01 | [Network](01-network/spec.md): VPC in 2 AZs, public and private subnets, one NAT Gateway per AZ, S3 gateway endpoint | Done |
| 01.02 | [EKS cluster](02-eks-cluster/spec.md): Auto Mode cluster, operator access entry, OIDC provider; `kubectl` runs a test pod | Done |
| 01.03 | [Data storage and access](03-data-storage/spec.md): bronze and Airbyte internal buckets, Airbyte IAM role (IRSA); policy tested | To do |
| 01.04 | [Argo CD](04-argo-cd/spec.md): Helm via Terraform and root Application pointing to `platform/aws`; UI by port-forward | To do |
| 01.05 | [Airbyte](05-airbyte/spec.md): chart v2 Application and StorageClass; healthy pods; UI reachable | To do |
| 01.06 | [Phase walkthrough](06-phase-walkthrough/spec.md): adds its phase README section, describing how the user creates source, destination (Parquet) and connection in the Airbyte UI, runs the sync, checks the Parquet files, then saves the configuration in `pipelines/airbyte/aws` with Terraform `import`; and the end-to-end walkthrough | To do |
