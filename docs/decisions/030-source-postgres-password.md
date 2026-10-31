# D-030 — Source Postgres Password

Status: Superseded by [D-031](031-source-postgres-password-from-env.md)
Date: 2026-10-31
Phase: specs/02-transactional-ingestion

## Context

The source Postgres ([D-022](022-source-postgres.md)) is a plain StatefulSet synced by Argo CD from
Git, and the official `postgres` image needs a superuser password. Secrets never go into the
repository, so the password must reach the cluster some other way. In phase 01 the question did not
come up, because the Airbyte chart generates its own database password.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Terraform `random_password` + `kubernetes_secret` in `infra/aws/gitops`; the StatefulSet reads the Secret | Common pattern; the password lives only in the local Terraform state (in `.gitignore`) and in the Secret | One resource pair in an existing root | None | Same on AKS and GKE (Kubernetes provider); reproducible from code |
| B. `kubectl create secret` run by hand from a documented command | Configuration outside code | Simplest | None | Not reproducible from code alone |
| C. External Secrets Operator + AWS Secrets Manager | Market standard for secrets on Kubernetes | One more operator, an IRSA role and a secret in AWS | About US$ 0.40 per secret-month | Needs a different secret store per cloud |

## Decision

- **Recommended:** A, because it is reproducible from code, adds no component and keeps the password
  out of Git; C adds an operator and a cloud service for a lab password.
- **Chosen:** A
- **Reason:** follows the recommendation.
- **Reading the password:** from the Secret with `kubectl` (no Terraform output), so it has a single
  place to be read.

## Sources

- [Docker official image: postgres](https://hub.docker.com/_/postgres)
- [Terraform: random_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password)
- [Terraform: kubernetes_secret_v1](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1)
