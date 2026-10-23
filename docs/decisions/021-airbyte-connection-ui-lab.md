# D-021 — Airbyte Connection as a UI Lab

Status: Accepted
Date: 2026-10-23
Phase: specs/01-ingestion-airbyte-s3

## Context

[D-010](010-airbyte-connection-config.md) chose the Airbyte Terraform provider, with objects created in
the UI and then saved as code with `import`. Airbyte does not document that flow: its practice is
configuration born as code (Terraform provider) and, for production, a dedicated external database
with backups. The Airbyte objects (source, destination, connection) live in Airbyte's Postgres,
bundled in the cluster ([D-009](009-airbyte-internal-storage.md)), so their IDs change with every new
environment.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Terraform provider, configuration born as code; the UI to run and monitor the sync | Airbyte's documented practice: versioned, reviewable, recreated with `terraform apply` | One more root; Airbyte credentials as environment variables; access by port-forward | Zero | Separate pipeline change stream ([D-003](003-terraform-root-layout.md)) |
| B. UI only, as a lab documented in the phase folder; the configuration is not saved | No history or drift detection; reproducible only by repeating the lab | Simplest: no code | Zero | The phase objective (API to Parquet in S3) is still proven |
| C. UI first, then saved as code with `import` (D-010) | Not documented by Airbyte; code generation from import is experimental in Terraform; import IDs are valid only in one environment | Complex | Zero | Meets all requirements |

## Decision

- **Recommended:** A, because it is Airbyte's documented practice for configuration as code.
- **Chosen:** B
- **Reason:** the user configures the connectors in the Airbyte UI and does not save that
  configuration; following the vendor's recommendation would require a highly reliable database,
  which the user considers not viable for large and mid-size companies.

## Sources

- [Airbyte: Terraform provider](https://docs.airbyte.com/platform/terraform-documentation)
- [Airbyte: external database for production](https://docs.airbyte.com/platform/deploying-airbyte/integrations/database)
- [Terraform: generating configuration (experimental)](https://developer.hashicorp.com/terraform/language/import/generating-configuration)
