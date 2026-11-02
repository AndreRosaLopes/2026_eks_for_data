# D-038 — Day Simulation with Part-Supplier Insert

Status: Accepted
Date: 2026-11-02
Phase: specs/02-transactional-ingestion
Supersedes: [D-037](037-day-simulation-by-table-type.md)

## Context

D-037 gives `partsupp` updates and deletes, but no inserts. Deletes only reach pairs that no line
item uses, now or in the future (`tpch`), and the SF1 data has only 459 of them. With the daily
amounts raised to 20 deletes a day, the deletes would stop on day 23. Everything else in D-037
stays: domains (`region`, `nation`) and `part` never change; facts (`orders`, `lineitem`) get
inserts and status updates, never deletes; `customer` gets inserts, updates and deletes (only
customers without orders); `supplier` gets inserts and updates.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Re-insert deleted pairs: pairs in `tpch.partsupp` missing from `oltp.partsupp` come back with their original values, before the day's delete | Every pair is a real TPC-H pair, so the foreign keys always hold | One statement | None | The pool never runs out (20 in, 20 out a day) |
| B. New pairs for new suppliers, with generated `availqty` and `supplycost` | New suppliers join the supply chain | More generated code; pairs not in TPC-H | None | Meets all requirements |
| C. No insert (D-037) | Nothing to change | Simplest | None | The deletes stop on day 23 |

## Decision

- **Recommended:** A, because it is the smallest change that keeps the simulation running indefinitely.
- **Chosen:** A
- **Reason:** follows the recommendation; the user noted that `partsupp` had no insert, so deleted
  pairs could come back.

## Sources

- [TPC-H specification](https://www.tpc.org/tpc_documents_current_versions/current_specifications5.asp) (part-supplier pairs)
