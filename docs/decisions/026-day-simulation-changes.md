# D-026 — Day Simulation Changes

Status: Accepted
Date: 2026-10-31
Phase: specs/02-transactional-ingestion

## Context

Each simulated day must produce inserts, updates and deletes, so lab02 (cursor) and lab03 (CDC) have changes to capture. Only CDC captures deletes. The lab is run to watch the system's behavior, not to be reproduced.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. One daily script with a reference date R: inserts the orders of day R from `tpch` (open); each open line item closes with a 10% chance per day, and any line item still open 30 days after its order closes; the order status follows its line items (O, P, F); 1% of the open orders are cancelled per day (order and line items deleted) | Realistic order lifecycle with all three kinds of change | One script, run daily | None | Covers the lab02 and lab03 Done When |
| B. Order status updates only, no deletes | Partly realistic | Simplest | None | Fails lab03 (deletes) |
| C. Random updates in any table | No business meaning | Simple | None | Meets the Done When, poor for learning |

## Decision

- **Recommended:** A, because it is the only alternative that produces inserts, updates and deletes with business meaning.
- **Chosen:** A
- **Reason:** follows the recommendation, simplified by the user: random behavior is allowed, because the lab is run to watch the system, not to be reproduced; a 10% daily closing chance with a 30-day limit, and 1% daily cancellations.

## Sources

- [TPC-H specification](https://www.tpc.org/tpc_documents_current_versions/current_specifications5.asp) (order and line item status)
