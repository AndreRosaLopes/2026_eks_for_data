# D-042 — Lab Bronze Layout

Status: Accepted
Date: 2026-11-02
Phase: specs/02-transactional-ingestion

## Context

Lab02 (date cursor) and lab03 (CDC) ingest the same 8 `oltp` tables into the bronze bucket. The S3
path is set on the Airbyte destination. The labs exist to compare the two methods, such as the
deletes only CDC captures.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. One S3 destination per lab: paths `oltp_cursor` (lab02) and `oltp_cdc` (lab03), Incremental \| Append | Each method's output separate and comparable, same table names | Two destinations in the UI | Same | Same bronze bucket as lab01 ([D-015](015-data-lake-bucket-layout.md)) |
| B. One destination; both labs share `oltp` | Files of both methods mixed | One destination | Same | Defeats the comparison |
| C. One destination; stream prefixes per connection (`cursor_`, `cdc_`) | Separate, but the method is hidden in table names | One destination | Same | Meets all requirements |

## Decision

- **Recommended:** A, because it keeps the methods apart with identical table names.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Airbyte: S3 destination](https://docs.airbyte.com/integrations/destinations/s3)
