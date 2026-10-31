# D-025 — Event Date Control

Status: Accepted
Date: 2026-10-31
Phase: specs/02-transactional-ingestion

## Context

TPC-H dates are in 1992–1998. The simulation needs orders that look current and that arrive one day at a time.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Shift the dates once, only in `oltp`, so the latest loaded day is load day − 1; each load takes a date range (`from`, `to`), so the daily inserts come from TPC-H; reference tables (`region`, `nation`, `supplier`, `part`, `partsupp`) use full refresh | `tpch` stays as generated; `oltp` behaves like a live system | One offset, computed once | None | Meets all requirements |
| B. Keep the TPC-H dates | Data looks historical | Simplest | None | Daily simulation has no meaning |

## Decision

- **Recommended:** A, because it makes `oltp` look current while `tpch` stays the untouched source.
- **Chosen:** A
- **Reason:** follows the recommendation.
