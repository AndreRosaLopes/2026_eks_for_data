# 02.07 — Registration Dates: Specification

Status: Implemented
Phase: [02 — Transactional Ingestion](../plan.md)

## Design

`created_at date NOT NULL` is added to `oltp.customer` and `oltp.supplier`
([D-034](../../../docs/decisions/034-registration-dates.md)), after `comment` and before
`updated_at`. The scripts run with the DuckDB CLI
([D-043](../../../docs/decisions/043-pipeline-script-execution.md)), through `postgres_execute`
([D-029](../../../docs/decisions/029-oltp-write-method.md)).

1. **Baseline** (`02-oltp-baseline.sql`): computed in the existing `CREATE TABLE ... AS` with a
   `LEFT JOIN`, no extra `UPDATE`. Dates are shifted by the same offset as the orders,
   `(current_date - 1) - cutoff`.

   | Table | `created_at` | Source |
   |---|---|---|
   | `customer` | Date of the customer's first order up to the cutoff, shifted | `min(o_orderdate)` from `tpch.orders` where `o_orderdate <= cutoff`, by `o_custkey` |
   | `supplier` | Order date of the first line item the supplier delivered up to the cutoff, shifted | `min(o_orderdate)` from `tpch.lineitem` joined to `tpch.orders`, where `o_orderdate <= cutoff`, by `l_suppkey` |
   | Both, without any order up to the cutoff | The baseline date: `current_date - 1`, the last loaded day | `coalesce(...)` |

   A customer whose first order is still in `tpch` (a future day) gets the baseline date, which is
   still before that order. `NOT NULL` is set with `ALTER TABLE` right after the CTAS (a CTAS
   cannot declare constraints).

2. **Day simulation** (`03-simulate-day.sql`): steps 4 (new customers) and 7 (new suppliers) set
   `created_at` to the simulated day R (`max(orderdate)` in `oltp.orders`, after step 3). Updates
   never change `created_at`.

3. **Applying it:** rerun `02-oltp-baseline.sql` (resets `oltp`), then `03-simulate-day.sql`; `tpch`
   is unchanged.

## Files

| File | Change |
|---|---|
| `pipelines/tpch/02-oltp-baseline.sql` | Modify: `created_at` in the `customer` and `supplier` CTAS (first order / first line item, otherwise the baseline date), `NOT NULL` |
| `pipelines/tpch/03-simulate-day.sql` | Modify: steps 4 and 7 set `created_at` = R |
| `specs/02-transactional-ingestion/README.md` | Modify: 02.07 section with the manual check |
| `specs/02-transactional-ingestion/plan.md` | Modify: step status |

## Verification Plan

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | Column exists | `\d oltp.customer` and `\d oltp.supplier` in `psql` | `created_at date not null`, before `updated_at` | Pass: position 9 of 10 (customer), 8 of 9 (supplier), `NO` nullable |
| 2 | Automated | Customers who bought | Customers whose `created_at` ≠ `min(orderdate)` of their `oltp` orders | 0 | Pass: 0 |
| 3 | Automated | Never registered after buying | Orders with `orderdate < customer.created_at`; line items whose order date is before `supplier.created_at` | 0 and 0 | Pass: 0 and 0; suppliers' `created_at` also equals their first line item's order date (0 mismatches) |
| 4 | Automated | Others get the baseline date | Customers and suppliers without orders up to the cutoff, and their `created_at` | All on the baseline date | Pass: 50,008 customers, all on 2026-11-01; every supplier has line items (0) |
| 5 | Automated | Simulation | Run `03-simulate-day.sql` once; rows whose `created_at` = R | 50 customers and 10 suppliers | Pass: R = 2026-11-02; 50 and 10 |
| 6 | Automated | Run time | Time of the baseline | Under 3 minutes | Pass: 100 seconds |
| 7 | Manual | Registration dates in the DuckDB UI | `SELECT min(created_at), max(created_at), count(*) FROM source.oltp.customer;` and the same for `supplier` | `min` near 2020-11, `max` = the latest simulated day; 150,020 customers and 10,010 suppliers after one simulated day | Pass: 2020-11-01 to 2026-11-02; 150,020 and 10,010 |

## Teardown

Not applicable: the column lives in `oltp`. Rerunning the 02.05 baseline recreates it, and the
Postgres volume goes at [Turn Off](../../../HOW_TO_RUN.md#51-turn-off).
