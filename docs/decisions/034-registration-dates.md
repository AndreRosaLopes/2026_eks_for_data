# D-034 — Registration Dates

Status: Accepted
Date: 2026-11-02
Phase: specs/02-transactional-ingestion

## Context

TPC-H has no registration date for customers or suppliers, and `updated_at` only records when the
baseline ran. In phase 03, the SCD type 2 history of a customer needs a start date for its first
version. Customers whose `custkey` is divisible by 3 never order; every supplier is used by some
line item.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Decide in phase 03, when the SCD type 2 model is built | Decide where the data is used | Nothing in phase 02 | None | Phase 02 is ingestion only |
| B. First version starts at the first ingestion date (`_airbyte_extracted_at`) | Common for sources without history | Nothing to generate | None | Fixes a phase 03 choice early |
| C. `created_at` in `oltp.customer` and `oltp.supplier`: the first order date (customer) or first line item date (supplier), shifted like the baseline; customers that never ordered get the baseline date; rows inserted by the day simulation get the simulated day | A transactional system records the registration date | One column per table in the baseline and in the simulation | None | Meets all requirements |

## Decision

- **Recommended:** A, because no phase 02 step uses the date.
- **Chosen:** C, with `supplier` included.
- **Reason:** a transactional system should record a registration date; the same rule applies to
  every registration table, so `supplier` gets it too. It differs from the recommendation.

## Sources

- [TPC-H specification](https://www.tpc.org/tpc_documents_current_versions/current_specifications5.asp) (customers without orders)
