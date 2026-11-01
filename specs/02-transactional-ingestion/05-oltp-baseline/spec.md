# 02.05 — OLTP Baseline: Specification

Status: Implemented
Phase: [02 — Transactional Ingestion](../plan.md)

## Design

One script, `pipelines/tpch/02-oltp-baseline.sql`, pasted and run in the DuckDB UI
([D-027](../../../docs/decisions/027-pipeline-scripts.md) C). Everything runs as native Postgres SQL
through `CALL postgres_execute('source', ...)`, one statement per call (Postgres refuses several
commands in one prepared statement)
([D-029](../../../docs/decisions/029-oltp-write-method.md)), so the data never leaves Postgres. It
ends with `CALL postgres_clear_cache()`, so DuckDB sees the new tables. The cutoff is a DuckDB
variable, inserted into the SQL with `replace(..., '{cutoff}', getvariable('cutoff'))`.

1. **Parameter (the only value to edit):** `cutoff`, a TPC-H date, default `1997-12-31`. Orders up
   to the cutoff form the baseline (6 years of history, about 1.36 million orders); later orders stay
   in `tpch` for the daily simulation (step 02.06): 214 days, up to 1998-08-02. The shift is
   `offset = (current_date - 1) - cutoff`, so the latest order lands on yesterday
   ([D-025](../../../docs/decisions/025-event-date-control.md)).
2. **Tables:** the 8 TPC-H tables in `oltp`, with the TPC-H prefix removed from every column (e.g.,
   `o_orderkey` → `orderkey`, `l_shipdate` → `shipdate`). Names such as `comment`, `name` and `type`
   are non-reserved Postgres keywords, valid without quotes.
3. **Keys:** primary keys (e.g., `orders(orderkey)`, `lineitem(orderkey, linenumber)`,
   `partsupp(partkey, suppkey)`) and foreign keys without cascade (e.g., `lineitem → orders`,
   `orders → customer`, `nation → region`).
4. **`updated_at`** on the 8 tables ([D-028](../../../docs/decisions/028-lab02-cursor.md)):
   `timestamptz NOT NULL DEFAULT now()` for inserts, and one trigger function
   `oltp.set_updated_at()` with a `BEFORE UPDATE` trigger on each table.
5. **Data:** reference tables (`region`, `nation`, `supplier`, `part`, `partsupp`, `customer`) in
   full; `orders` and `lineitem` only up to the cutoff, with `orderdate`, `shipdate`, `commitdate`
   and `receiptdate` shifted. Statuses
   ([D-026](../../../docs/decisions/026-day-simulation-changes.md)): line items whose order is 30 days
   or older are closed (`linestatus = 'F'`), the last 30 days are open (`'O'`), and `orderstatus`
   follows its line items (O, P, F).
6. **Rerun = reset:** the script drops and recreates `oltp`, restarting the simulation from
   yesterday; `tpch` is never changed.

The daily script finds the offset without a configuration table: keys are kept, so it is
`oltp.orders.orderdate - tpch.orders.o_orderdate` for any order.

## Files

| File | Change |
|---|---|
| `pipelines/tpch/02-oltp-baseline.sql` | Create: the baseline script |
| `specs/02-transactional-ingestion/README.md` | Modify: the 02.05 section |
| `specs/02-transactional-ingestion/plan.md` | Modify: step status |

## Verification Plan

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | Script runs | The script through `kubectl exec -i deploy/duckdb -- /duckdb` | No errors | Pass: no errors, 86 seconds at SF1 |
| 2 | Automated | Counts | Reference tables `oltp` vs `tpch`; `oltp.orders` vs `tpch.orders` up to the cutoff | Equal | Pass: reference tables equal; orders 1,366,377 = 1,366,377; lineitem 5,466,188 = 5,466,188 |
| 3 | Automated | Shift | `max(orderdate)` in `oltp.orders` | Yesterday (`current_date - 1`) | Pass: 2026-10-30 = yesterday |
| 4 | Automated | No prefixes | Column names in `information_schema.columns` for `oltp` | No `x_` prefix; `updated_at` on every table | Pass: 0 prefixed columns; `updated_at` on 8 tables |
| 5 | Automated | Keys | `information_schema.table_constraints` and `referential_constraints` | 8 primary keys; foreign keys with `NO ACTION` on delete | Pass: 8 primary keys; 8 foreign keys, all `NO ACTION` |
| 6 | Automated | Trigger | `UPDATE` one order (`comment = comment`) and compare its `updated_at` | `updated_at` changes | Pass: `updated_at` changed. The update was committed (not rolled back): order 1 kept a later `updated_at`, cleared by the next baseline run |
| 7 | Automated | Statuses | Open line items 30+ days old; orders whose status disagrees with their line items | 0 and 0 | Pass: 0 open line items 30+ days old; 0 status mismatches |
| 8 | Manual | Baseline through the UI | Paste the script into the UI, run it, then run the README queries | Columns without prefix; latest `orderdate` = yesterday; counts as in the README | Pass: confirmed by the user |

## Teardown

Not applicable on its own: `oltp` goes with the Postgres volume. Rerunning the script resets it.
