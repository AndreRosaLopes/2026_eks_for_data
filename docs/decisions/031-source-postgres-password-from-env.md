# D-031 — Source Postgres Password from `.env`

Status: Accepted
Date: 2026-10-31
Phase: specs/02-transactional-ingestion
Supersedes: [D-030](030-source-postgres-password.md)

## Context

D-030 created the source Postgres password with Terraform (`random_password` + `kubernetes_secret`
in `infra/aws/gitops`). That adds a file, two providers and a dependency to the code only to carry a
password. The project favors code a layperson can read (principle 2).

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Terraform `random_password` + `kubernetes_secret` (D-030) | Common pattern; automatic order through `depends_on` | 1 file, 2 providers, 1 `depends_on` | None | Reproducible from code |
| B. Password in the local `.env`; `kubectl create secret` from it | Configuration partly outside code; the order (Secret before the sync) is a manual step | No code; 2 documented commands | None | Reproducible from code plus documented commands; same on AKS and GKE |

## Decision

- **Recommended:** A, because it is automatic and reproducible from code alone.
- **Chosen:** B
- **Reason:** simplicity of the code (principle 2): no Terraform only to carry a password. The
  password stays out of Git, because `.env` is in `.gitignore`.
- **How:** `.env` holds `POSTGRES_PASSWORD` and, as a comment, the two `kubectl` commands; the
  `postgres` namespace is also declared in `platform/aws/postgres.yaml`, so Argo CD deletes it, with
  the Secret, at teardown.

## Sources

- [Kubernetes: managing Secrets using kubectl](https://kubernetes.io/docs/tasks/configmap-secret/managing-secret-using-kubectl/)
- [Docker official image: postgres](https://hub.docker.com/_/postgres)
