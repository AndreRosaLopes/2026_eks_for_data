[Labs](README.md) › 2.02

# Lab 2.02 — OLTP Baseline and Day Simulation

## Goal

Build the `oltp` schema, the transactional system that Airbyte reads, from the TPC-H data in
`tpch`. Its dates are shifted so the last order is yesterday. Then simulate days of activity: each
run adds one day of new orders, ships line items, and inserts, updates and deletes customers,
suppliers and part-supplier pairs.

## Prerequisites

1. [Lab 2.01 — TPC-H Generation](lab_ingestion_2.01.md) done: `tpch` has the 8 tables.
2. Postgres and DuckDB running, from the repository root in Git Bash:

   ```bash
   kubectl -n argocd get applications postgres duckdb
   ```

   Expected: both `Synced` and `Healthy`.

3. The DuckDB UI open. In a second Git Bash window, leave this loop running:

   ```bash
   while true; do kubectl -n duckdb port-forward deploy/duckdb 4213:4213; sleep 1; done
   ```

   Open `http://localhost:4213`. The local port must be 4213. The tunnel often drops
   (`lost connection to pod`): the loop reconnects it, then reload the page.

## Concepts

- **OLTP (Online Transaction Processing):** a database that records a business's daily operations
  row by row: new orders, address changes, deletions. `oltp` plays that role; `tpch` stays
  untouched as the source of future orders.
- **Cutoff and date shift:** orders up to the cutoff date (`1997-12-31`) go into `oltp`, and every
  date is moved forward by the same number of days so the cutoff becomes yesterday. Later orders
  stay in `tpch` and arrive one day at a time through the simulation
  ([D-025](../decisions/025-event-date-control.md)).
- **Order status:** `O` (open, no line item shipped), `P` (partial, some shipped) and `F`
  (finished, all shipped). In the baseline, orders from the last 30 days are `O` and older ones
  `F`; each line item's status (`linestatus`) follows its order.
- **Column names without prefixes:** `oltp` drops the TPC-H prefixes (`o_orderkey` becomes
  `orderkey`), as a typical application database would.
- **`created_at`:** the registration date of a customer or supplier, which TPC-H lacks. It is the
  date of their first order (customer) or first line item (supplier), shifted; without one, it is
  yesterday ([D-034](../decisions/034-registration-dates.md)).
- **`updated_at` and its trigger:** every `oltp` table has `updated_at`. An insert sets it to the
  current time (column default); an update sets it again through a trigger, a function Postgres
  runs on every row change. Airbyte's date cursor (incremental reads by `updated_at`) depends on it
  ([D-028](../decisions/028-lab02-cursor.md)).
- **Primary and foreign keys without cascade:** each table has a primary key (the unique key of a
  row), and foreign keys check that every reference exists, for example that each order's
  customer exists. Nothing is deleted in cascade: every delete is explicit in the script
  ([D-029](../decisions/029-oltp-write-method.md)).
- **`postgres_execute`:** runs one statement directly in Postgres, in Postgres' own SQL. The
  scripts use it for every change in `oltp`, so the data never travels through DuckDB and the
  trigger fires natively.
- **Simulated day R:** the day after the latest order in `oltp`. The first run simulates today,
  the second tomorrow, and so on.
- **Facts and dimensions:** facts are business events (`orders`, `lineitem`); dimensions describe
  who and what (`customer`, `supplier`, `partsupp`). What changes each day
  ([D-038](../decisions/038-day-simulation-with-partsupp-insert.md)):

  | Table | Insert | Update | Delete |
  |---|---|---|---|
  | `orders`, `lineitem` | The day's orders from `tpch` | Status (shipping) | Never |
  | `customer` | 50 new | 100 get a new address, phone and segment | 30 that have no order, now or in `tpch` |
  | `supplier` | 10 new | 50 get a new address, phone and balance | Never |
  | `partsupp` | 20 pairs deleted on earlier days come back | 200 get new stock and cost | 20 pairs no line item uses |
  | `region`, `nation`, `part` | Never | Never | Never |

  The updated customers are those whose `custkey` is divisible by 3: TPC-H gives them no orders.
  Their changes feed the SCD type 2 history (Slowly Changing Dimension: one version per change) of
  the transformation labs.

## Steps

### 1. Read the Baseline Script

Open `pipelines/tpch/02-oltp-baseline.sql`:

1. `SET VARIABLE cutoff = '1997-12-31';`: the TPC-H date that becomes yesterday. It accepts any
   date from `'1992-01-01'` to `'1998-08-02'`; the last one loads every order and leaves none for
   the simulation. Keep it.
2. Drops and recreates `oltp`, so a rerun resets it.
3. Copies `region`, `nation`, `supplier`, `customer`, `part` and `partsupp` in full, without
   prefixes; `supplier` and `customer` get `created_at`.
4. Copies the orders up to the cutoff, shifted, with status `O` or `F`, then their line items.
5. Adds the primary keys, the foreign keys, `updated_at` and the triggers.
6. Ends with a summary of the orders.

### 2. Run the Baseline

From the repository root (about 2 minutes):

```bash
MSYS_NO_PATHCONV=1 kubectl -n duckdb exec -i deploy/duckdb -- /duckdb < pipelines/tpch/02-oltp-baseline.sql
```

Expected: no errors, and the summary:

| Column | Value |
|---|---|
| `orders` | 1,366,377 |
| `first_order` | About six years before yesterday |
| `last_order` | Yesterday |
| `open_orders` | About 18,000 (the orders of the last 30 days) |

### 3. Explore the Baseline

In the DuckDB UI, run each query in its own cell.

```sql
DESCRIBE source.oltp.orders;
```

Expected: `orderkey`, `custkey`, `orderstatus`, …, `comment`, `updated_at`, with no `o_` prefix.

```sql
SELECT orderstatus, min(orderdate), max(orderdate), count(*)
FROM source.oltp.orders GROUP BY orderstatus;
```

Expected: `F` with about 1,348,000 orders, up to 30 days ago; `O` with about 18,000, from 29 days
ago to yesterday.

### 4. Read the Simulation Script

Open `pipelines/tpch/03-simulate-day.sql`:

1. The `SET VARIABLE` lines at the top: the number of dimension changes per day (table in
   [Concepts](#concepts)). Keep them.
2. **Facts:** each open line item ships with a 10% chance, and always once its order is 30 days old;
   each order's status follows its line items (`O`, `P` or `F`); the `tpch` orders of day R arrive
   with their line items, all open.
3. **Dimensions:** the customer, supplier and part-supplier changes, in the order of the table.
4. Ends with a summary of the day.

### 5. Simulate One Day

About 1 minute:

```bash
MSYS_NO_PATHCONV=1 kubectl -n duckdb exec -i deploy/duckdb -- /duckdb < pipelines/tpch/03-simulate-day.sql
```

Expected summary:

| Column | Value |
|---|---|
| `simulated_day` | Today |
| `new_orders` | About 600 |
| `open_orders`, `partial_orders`, `finished_orders` | All three above zero |
| `customers` | 150,020 (50 new, 30 deleted) |
| `suppliers` | 10,010 |
| `partsupp` | 799,980 (no pair to bring back yet, 20 deleted) |

### 6. Simulate a Second Day

Run the same command again.

Expected: `simulated_day` is tomorrow, `customers` 150,040, `suppliers` 10,020, and `partsupp`
stays 799,980 (20 pairs back, 20 deleted).

## Validation

In the DuckDB UI:

```sql
SELECT 'customer' AS t, min(created_at), max(created_at), count(*) FROM source.oltp.customer
UNION ALL
SELECT 'supplier', min(created_at), max(created_at), count(*) FROM source.oltp.supplier;
```

Expected: for both, `min` about six years ago and `max` the latest simulated day.

```sql
SELECT orderdate, orderstatus, count(*) AS orders
FROM source.oltp.orders
WHERE orderdate >= current_date - 1
GROUP BY ALL ORDER BY ALL;
```

Expected: yesterday's orders and the two simulated days, with open (`O`) and some partial (`P`)
orders.

## Questions

1. Why are the dates shifted only in `oltp` and never in `tpch`?
2. Which tables get deletes, and why can a deleted customer never be one with orders?
3. Why does `updated_at` need a trigger instead of being set by the script?
4. After running the baseline again, which day does the next simulation produce?

## Cleanup

Nothing to clean: labs 2.03 and the ingestion labs read `oltp`. Running the baseline again resets
`oltp` and drops the tables from the CDC publication of lab 2.03: run lab 2.03 again after it.
