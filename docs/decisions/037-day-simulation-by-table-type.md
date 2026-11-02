# D-037 — Day Simulation by Table Type

Status: Superseded by [D-038](038-day-simulation-with-partsupp-insert.md)
Date: 2026-11-01
Phase: specs/02-transactional-ingestion
Supersedes: [D-026](026-day-simulation-changes.md), [D-035](035-scd2-customer-changes.md)

## Context

D-026 cancelled orders by deleting them. Events are facts: they may be updated by a later event (a
line item ships), but never deleted, and TPC-H has no cancellation state (`orderstatus` is only
O, P, F; `linestatus` only O, F). Inserts, updates and deletes must still happen, so lab03 shows
that only CDC captures deletes, and they must stay coherent: no order may reference a deleted row,
including future orders still in `tpch`. In the SF1 data, 50,004 customers and 459 part-supplier
pairs are never used by any order; every supplier and every part is.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Changes by table type, all in the daily script: domains (`region`, `nation`) never change; facts (`orders`, `lineitem`) get inserts and status updates, never deletes; dimensions: `customer` insert, update, delete (only customers without orders); `supplier` insert and update; `partsupp` update and delete (only pairs never sold); `part` unchanged | Events immutable except by later events; deletes only where nothing references the row; TPC-H states only | One script, one run per day | None | Covers lab02 and lab03 (deletes on dimensions) |
| B. Same changes, dimensions in a separate script run by hand | Same | Two scripts | None | Dimension changes only when run |
| C. D-026 as it was (order cancellation by delete) | Deletes events; no TPC-H cancellation state | One script | None | Contradicts immutable events |

## Decision

- **Recommended:** A, because it keeps events immutable, stays within the TPC-H states, and gives
  every simulated day inserts, updates and deletes in one run.
- **Chosen:** A
- **Reason:** the user set the rules: events are never deleted, TPC-H has no cancellation, only
  rows that no order uses may be deleted, and domains do not change. Customer updates keep the
  D-035 choice of customers that never bought.

## Sources

- [TPC-H specification](https://www.tpc.org/tpc_documents_current_versions/current_specifications5.asp) (order and line item status)
