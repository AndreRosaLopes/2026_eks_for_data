# D-008 — Pod Identity for AWS Access

Status: Accepted
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

Airbyte pods must read and write S3 (its internal storage and the bronze bucket) without
secrets in the repository.

Known divergence: on GCP, the Airbyte GCS destination supports only HMAC keys, so a secret
(kept outside the repository) will be needed there.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. IRSA | Recommended by AWS together with Pod Identity; works with the default credential chain used by Airbyte (`instanceProfile` for storage, no keys for the S3 destination); reported working with Airbyte on the Airbyte forum (non-official source) | OIDC provider (created by the module) + ServiceAccount annotation | Zero | Same OIDC federation model as AKS Workload Identity and GKE Workload Identity Federation |
| B. EKS Pod Identity | AWS preference "unless you have specific use cases for IRSA" | No OIDC; preconfigured in Auto Mode | Zero | Equivalents exist; compatibility with Airbyte not confirmed (an unresolved failure report on the forum) |
| C. IAM user access keys in a Secret | Long-lived credential, against best practice | Manual step | Zero | Weaker reproducibility; the secret stays outside the repository |

## Decision

- **Recommended:** A, because the uncertain Airbyte compatibility is the "specific use case"
  AWS mentions.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [EKS best practices: Pod Identities compared to IRSA](https://docs.aws.amazon.com/eks/latest/best-practices/identity-and-access-management.html)
- [Airbyte: storage (`instanceProfile`)](https://docs.airbyte.com/platform/deploying-airbyte/integrations/storage)
- [Airbyte: S3 destination](https://docs.airbyte.com/integrations/destinations/s3)
- [Airbyte: GCS destination](https://docs.airbyte.com/integrations/destinations/gcs)
- [Airbyte forum: service accounts for AWS authentication](https://discuss.airbyte.io/t/using-service-accounts-for-aws-authentication-with-airbyte/7341) (non-official)
- [Airbyte forum: EKS Pod Identity](https://discuss.airbyte.io/t/using-eks-pod-identity-with-kubernetes-airbyte-deployment/7748) (non-official)
