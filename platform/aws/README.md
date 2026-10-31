# platform/aws

Kubernetes manifests for the AWS cluster. Every `.yaml` file in this folder is synced by the Argo CD
root Application `platform` ([step 01.04](../../specs/01-ingestion-airbyte-s3/04-argo-cd/spec.md)).
Each component is its own Application ([D-032](../../docs/decisions/032-one-application-per-component.md)):
a Helm chart (`airbyte.yaml`) or a subfolder of plain manifests (`postgres.yaml` → `postgres/`).
