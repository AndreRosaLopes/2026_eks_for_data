# D-004 — Terraform Modules

Status: Accepted
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

The VPC, EKS cluster and IAM roles can be written with community modules or with raw resources.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. `terraform-aws-modules` (vpc 6.7, eks 21.29, iam 6.8) | Market standard (hundreds of millions of downloads); Auto Mode and IRSA built in | Little code | Same | Equivalent to Azure Verified Modules and `terraform-google-modules` |
| B. Raw `aws_*` resources | Higher risk of misconfiguration (IAM, security groups, OIDC, access entries) | Much more code | Same | Meets all requirements |

## Decision

- **Recommended:** A, because it is the market standard and needs much less code.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [terraform-aws-modules/eks](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws)
- [terraform-aws-modules/vpc](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws)
- [terraform-aws-modules/iam](https://registry.terraform.io/modules/terraform-aws-modules/iam/aws)
