# D-020 — AWS Account ID in the Public Repository

Status: Accepted
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

Argo CD reads the Airbyte configuration from this public repository. It needs the IRSA role ARN
(`eks.amazonaws.com/role-arn` on the ServiceAccount, [D-008](008-pod-aws-identity.md)) and the
bucket names, and both contain the AWS account ID. Until now the account ID only lived in the
unversioned `.env`.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Role ARN and bucket names in the manifest in `platform/aws` | AWS: account IDs "are not considered secret, sensitive, or confidential", though they should be shared carefully | Simple; everything in Git | Zero | Pure GitOps; another account only changes this file |
| B. Terraform (`gitops` root) creates the Airbyte Application and injects the values | Account ID out of Git | The Application leaves `platform/aws`, breaking the app-of-apps of 01.04 and mixing change streams | Zero | Departs from [D-007](007-argo-cd-installation.md) and step 01.04 |
| C. Private repository | Account ID out of public view | Argo CD needs a Git credential: one more secret to manage | Zero | Departs from D-007 ("public repository, so no credentials") |

## Decision

- **Recommended:** A, because AWS does not classify the account ID as a secret, and the alternatives
  break approved decisions.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [AWS account identifiers](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-identifiers.html)
