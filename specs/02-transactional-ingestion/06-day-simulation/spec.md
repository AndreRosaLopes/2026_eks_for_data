# 02.06 — Day Simulation: Specification

Status: Approved
Phase: [02 — Transactional Ingestion](../plan.md)

## Design

One script, `pipelines/tpch/03-simulate-day.sql`, pasted and run in the DuckDB UI
([D-027](../../../docs/decisions/027-pipeline-scripts.md) C), with native Postgres SQL through
`postgres_execute`, one statement per call ([D-029](../../../docs/decisions/029-oltp-write-method.md)).
One run = one day: the simulated day R is the day after the latest order in `oltp`; nothing is
edited. The offset is `oltp.orderdate - tpch.o_orderdate`, read from any order (02.05).

Changes by table type ([D-038](../../../docs/decisions/038-day-simulation-with-partsupp-insert.md)):

| Table | Type | Insert | Update | Delete |
|---|---|---|---|---|
| `region`, `nation` | Domain | No | No | No |
| `orders` | Fact | Orders of day R from `tpch`, open | `orderstatus` O → P → F, from its line items | No |
| `lineitem` | Fact | Line items of day R, open | `linestatus` O → F: 10% chance per day, always once the order is 30 days old relative to R | No |
| `customer` | Dimension | 50 new customers | 100 customers that never bought: address, phone, segment | 30 customers with no order in `oltp` or `tpch` |
| `supplier` | Dimension | 10 new suppliers | 50 suppliers: address, phone, balance | No (every TPC-H supplier is in use) |
| `partsupp` | Dimension | 20 pairs deleted on earlier days, back from `tpch` (runs before the delete) | 200 pairs: `availqty`, `supplycost` | 20 pairs no line item uses in `oltp` or `tpch` |
| `part` | Dimension | No | No | No |

The amounts per day are `SET VARIABLE` lines at the top of the script; at SF1 each stays under
1% of its table per day. The `partsupp` insert keeps the 459 deletable pairs from running out. Deletes only reach rows that no
order uses, now or in the future (`tpch`), so the foreign keys always hold. The trigger updates
`updated_at` on every update ([D-028](../../../docs/decisions/028-lab02-cursor.md)). The run ends with
a summary: R, new orders, orders per status, and the customer, supplier and `partsupp` counts.

Implementation notes: `random()` sits in a condition on `lineitem` itself (a condition on `orders`
only draws once per order, and whole orders close); the 30-day subquery lists only orders not yet
finished, so Postgres can hash it (listing all old orders made the update run for over 10 minutes).

## Files

| File | Change |
|---|---|
| `pipelines/tpch/03-simulate-day.sql` | Create: the daily simulation |
| `platform/aws/postgres/postgres.yaml` | Modify: 512Mi memory-backed `/dev/shm`, so parallel queries do not fail |
| `specs/02-transactional-ingestion/README.md` | Modify: the 02.06 section |
| `specs/02-transactional-ingestion/plan.md` | Modify: step status |

## Verification Plan

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | Day advances; facts only grow | Run the script; `max(orderdate)` and order count before and after | One day later; orders = before + new orders of day R (no deletes) | Pass: 2026-11-02 → 2026-11-03; 1,367,390 + 586 = 1,367,976 |
| 2 | Automated | Status updates | Partial orders; open line items whose order is 30+ days old | Partial orders appear; 0 open line items 30+ days old | Pass: partial orders 8,691 → 10,514; 0 |
| 3 | Automated | Dimension changes | Counts before and after; rows with the newest `updated_at` | customer +50 −30; supplier +10; `partsupp` +20 −20 (first run: +0, nothing deleted yet); 100 customers, 50 suppliers and 200 pairs updated | Pass: 150,000 → 150,020 → 150,040; 10,000 → 10,010 → 10,020; 800,000 → 799,980 → 799,980; 50 customers inserted and 100 updated, 10 suppliers inserted and 50 updated, 200 pairs updated |
| 4 | Automated | Run time | Time of one run | Under 2 minutes | Pass: 48 s and 69 s |
| 5 | Manual | Through the UI | Run the script once and read its summary | `simulated_day` one day later, about 600 new orders, open/partial/finished orders, and the changed dimension counts | Pending |

## Teardown

Not applicable: the changes live in `oltp`. Rerunning the 02.05 baseline resets them.
