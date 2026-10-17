# D-014 — EKS API Data Encryption

Status: Accepted
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

By default, the `terraform-aws-modules/eks` module creates a customer managed KMS key (key, alias and
IAM encryption policy) to encrypt the cluster Secrets. Since Kubernetes 1.28, EKS already applies
envelope encryption to all Kubernetes API data with an AWS owned key, with no configuration.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. EKS default encryption (`create_kms_key = false`, `encryption_config = null`) | Data stays encrypted (AWS default envelope encryption) | 3 fewer resources; nothing left behind on destroy | Zero | AKS and GKE also encrypt etcd by default with a platform key |
| B. Module default: customer managed KMS key | More control over the key (rotation, revocation, KMS audit); common in regulated environments | More resources; on destroy the key stays "pending deletion" for up to 30 days, one per cluster re-creation | US$ 1/month per key (prorated hourly); no charge while pending deletion | AKS and GKE also accept a customer managed key |

## Decision

- **Recommended:** A, because data protection already exists by default and a customer key only adds
  resources and leftovers in an environment created and destroyed often (principle 2).
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Default envelope encryption for all Kubernetes API data](https://docs.aws.amazon.com/eks/latest/userguide/envelope-encryption.html)
- [AWS KMS pricing](https://aws.amazon.com/kms/pricing/)
- [terraform-aws-modules/eks variables (`create_kms_key`, `encryption_config`)](https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v21.29.0/variables.tf)
