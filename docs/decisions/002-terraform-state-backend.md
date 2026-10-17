# D-002 — Terraform State Backend

Status: Accepted
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

Terraform keeps a state file that maps the code to the real resources. It must be stored somewhere,
and it contains sensitive data.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. S3 backend with `use_lockfile` (bucket created by a bootstrap root with local state) | Remote, versioned, locked state; DynamoDB locking is deprecated by HashiCorp | One extra root, applied once | Cents | Equivalent to `azurerm` (lease lock) and `gcs` (native lock) backends |
| B. Local state (gitignored file) | No lock and no backup; sensitive state only on the local disk | Simplest | Zero | Meets all requirements |
| C. HCP Terraform | Best practice, but an external SaaS | Extra account and login | Limited free tier | Same on all three clouds, but does not use the native object storage |

## Decision

- **Recommended:** A, because remote, locked state is the market best practice (principle 1).
- **Chosen:** B
- **Reason:** simplicity for an ephemeral environment with a single operator: no bootstrap
  root, and the environment is destroyed after use. This does not follow the principle
  priority order (simplicity over best practices).

## Sources

- [Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3)
