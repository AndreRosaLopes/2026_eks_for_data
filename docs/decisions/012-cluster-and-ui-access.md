# D-012 — Cluster and UI Access

Status: Accepted
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

The operator needs access to the Kubernetes API and to the Argo CD and Airbyte UIs.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Public EKS endpoint restricted to the operator's IP (`public_access_cidrs`) + `kubectl port-forward` for Argo CD and Airbyte | IAM authentication; no application exposed to the internet | Simplest | Zero | AKS and GKE have authorized IP ranges; port-forward is identical |
| B. ALB via Ingress (+ DNS, TLS, authentication) | Exposes the UIs; needs a domain and authentication | More complex | ALB per hour + LCU | Meets all requirements |
| C. Private endpoint + SSM bastion or VPN | Most secure | Complex | Extra | Meets all requirements |

## Decision

- **Recommended:** A, because it exposes nothing but the IAM-protected API, at zero cost.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [EKS cluster endpoint access control](https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html)

## Update — 2026-10-31: Operator IP Detected by Terraform

The operator IP was a variable (`operator_cidr`) exported before every `plan`, an easy step to forget.

- **Change:** the `hashicorp/http` provider reads `https://checkip.amazonaws.com` at plan time, and
  `endpoint_public_access_cidrs` uses that IP with `/32`. The variable is removed.
- **Effect:** no manual step; if the IP changes, a new `plan`/`apply` updates the allowed range. The
  IP still stays out of Git.
- **Source:** [Terraform Registry: hashicorp/http](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http)
