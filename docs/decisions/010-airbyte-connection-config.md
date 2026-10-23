# D-010 — Airbyte Connection Configuration

Status: Superseded by D-021
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

Once Airbyte is running, the source, destination and connection must be created in it.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Terraform provider `airbytehq/airbyte` (1.3.0, partner tier) in `pipelines/airbyte/aws` | Configuration as code: versioned, `terraform plan` shows drift; the UI stays available, and UI-made objects can be saved with `import` | One more root; Airbyte credentials as environment variables; access by port-forward | Zero | Separate pipeline change stream; reproducible with one command; same on all clouds |
| B. Manual in the UI, documented step by step in the README | No history; nothing detects drift between UI and README | Simplest | Zero | Reproducible only by repeating the steps manually |
| C. Script calling the Airbyte API | Imperative | More code | Zero | Meets all requirements |

## Decision

- **Recommended:** A, because configuration as code is the best practice and keeps the pipeline
  history in its own change stream.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Terraform Registry: airbytehq/airbyte](https://registry.terraform.io/providers/airbytehq/airbyte)
- [airbyte_connection resource: import](https://github.com/airbytehq/terraform-provider-airbyte/blob/main/docs/resources/connection.md)
