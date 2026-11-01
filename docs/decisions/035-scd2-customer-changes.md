# D-035 — SCD Type 2 Customer Changes

Status: Superseded by [D-037](037-day-simulation-by-table-type.md)
Date: 2026-10-31
Phase: specs/02-transactional-ingestion

## Context

The user wants customers that never bought to receive changes by hand, to create SCD type 2 history. In TPC-H, customers whose `c_custkey` is divisible by 3 have no orders.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Separate script, run by hand: changes `c_address`, `c_phone` and `c_mktsegment` of N customers that never bought (N is a parameter); the trigger updates `updated_at` | Typical SCD type 2 attributes; one script, one purpose | One short script | None | Matches "run by hand" |
| B. Inside the daily simulation | Mixes two purposes | One script fewer | None | Contradicts "run by hand" |

## Decision

- **Recommended:** A, because it does what the user described without touching the order simulation.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [TPC-H specification](https://www.tpc.org/tpc_documents_current_versions/current_specifications5.asp) (customers without orders)
