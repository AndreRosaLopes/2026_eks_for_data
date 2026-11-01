-- 02.06 — Day simulation in oltp (D-037, D-029). Paste and run in the DuckDB UI.
-- One run = one day: the simulated day R is the day after the latest order in oltp.
-- Facts (orders, lineitem): inserts and status updates, never deletes.
-- Dimensions: customer (insert, update, delete), supplier (insert, update),
-- partsupp (update, delete). Domains (region, nation) and part never change.
-- Only rows that no order uses, now or in the future (tpch), are deleted.
-- Each postgres_execute runs one native Postgres statement.

-- Changes per day
SET VARIABLE new_customers = 5;
SET VARIABLE changed_customers = 10;
SET VARIABLE deleted_customers = 3;
SET VARIABLE new_suppliers = 1;
SET VARIABLE changed_suppliers = 5;
SET VARIABLE changed_partsupp = 20;
SET VARIABLE deleted_partsupp = 2;

-- Already attached in the UI; needed in a new DuckDB process
ATTACH IF NOT EXISTS '' AS source (TYPE postgres);

-- FACTS ---------------------------------------------------------------------------------------

-- 1. Line items ship: each open line item closes with a 10% chance, and always once its order is
--    30 days old relative to R (random() is drawn per line item, so an order can become partial)
CALL postgres_execute('source', $sql$
UPDATE oltp.lineitem
SET linestatus = 'F'
WHERE linestatus = 'O'
  AND (random() < 0.10
       OR orderkey IN (SELECT orderkey FROM oltp.orders
                       WHERE orderstatus <> 'F'
                         AND orderdate <= (SELECT max(orderdate) + 1 FROM oltp.orders) - 30))
$sql$);

-- 2. Order status follows its line items: O (all open), P (mixed), F (all shipped)
CALL postgres_execute('source', $sql$
UPDATE oltp.orders o
SET orderstatus = s.status
FROM (
  SELECT orderkey,
         CASE WHEN bool_and(linestatus = 'F') THEN 'F'
              WHEN bool_and(linestatus = 'O') THEN 'O'
              ELSE 'P' END AS status
  FROM oltp.lineitem
  WHERE orderkey IN (SELECT orderkey FROM oltp.orders WHERE orderstatus <> 'F')
  GROUP BY orderkey
) s
WHERE s.orderkey = o.orderkey AND o.orderstatus <> s.status
$sql$);

-- 3. New orders: the tpch orders of day R, dates shifted like the baseline, all open
CALL postgres_execute('source', $sql$
WITH p AS (
  SELECT (SELECT max(orderdate) + 1 FROM oltp.orders) AS r,
         (SELECT o.orderdate - t.o_orderdate
          FROM oltp.orders o JOIN tpch.orders t ON t.o_orderkey = o.orderkey LIMIT 1) AS shift_days
)
INSERT INTO oltp.orders (orderkey, custkey, orderstatus, totalprice, orderdate, orderpriority,
                         clerk, shippriority, comment)
SELECT o_orderkey, o_custkey, 'O', o_totalprice, o_orderdate + p.shift_days, o_orderpriority,
       o_clerk, o_shippriority, o_comment
FROM tpch.orders, p
WHERE o_orderdate + p.shift_days = p.r
$sql$);

CALL postgres_execute('source', $sql$
WITH p AS (
  SELECT (SELECT max(orderdate) FROM oltp.orders) AS r,
         (SELECT o.orderdate - t.o_orderdate
          FROM oltp.orders o JOIN tpch.orders t ON t.o_orderkey = o.orderkey LIMIT 1) AS shift_days
)
INSERT INTO oltp.lineitem (orderkey, partkey, suppkey, linenumber, quantity, extendedprice,
                           discount, tax, returnflag, linestatus, shipdate, commitdate,
                           receiptdate, shipinstruct, shipmode, comment)
SELECT l_orderkey, l_partkey, l_suppkey, l_linenumber, l_quantity, l_extendedprice,
       l_discount, l_tax, l_returnflag, 'O', l_shipdate + p.shift_days,
       l_commitdate + p.shift_days, l_receiptdate + p.shift_days, l_shipinstruct, l_shipmode,
       l_comment
FROM tpch.lineitem
JOIN oltp.orders o ON o.orderkey = l_orderkey
CROSS JOIN p
WHERE o.orderdate = p.r
$sql$);

-- DIMENSIONS ----------------------------------------------------------------------------------

-- 4. Customer insert: new customers (no order will reference them)
CALL postgres_execute('source', replace($sql$
INSERT INTO oltp.customer (custkey, name, address, nationkey, phone, acctbal, mktsegment, comment)
SELECT k, 'Customer#' || lpad(k::text, 9, '0'), substr(md5(random()::text), 1, 20), nk,
       (10 + nk) || '-' || (100 + floor(random() * 900))::int || '-'
         || (100 + floor(random() * 900))::int || '-' || (1000 + floor(random() * 9000))::int,
       round((random() * 10998.99 - 999.99)::numeric, 2),
       (ARRAY['AUTOMOBILE', 'BUILDING', 'FURNITURE', 'HOUSEHOLD', 'MACHINERY'])
         [1 + floor(random() * 5)::int],
       'new customer'
FROM (SELECT (SELECT max(custkey) FROM oltp.customer) + g AS k, floor(random() * 25)::int AS nk
      FROM generate_series(1, {n}) g) x
$sql$, '{n}', getvariable('new_customers')::VARCHAR));

-- 5. Customer update (SCD type 2): customers that never bought get a new address, phone and segment
CALL postgres_execute('source', replace($sql$
UPDATE oltp.customer c
SET address = substr(md5(random()::text), 1, 20),
    phone = (10 + c.nationkey) || '-' || (100 + floor(random() * 900))::int
            || '-' || (100 + floor(random() * 900))::int
            || '-' || (1000 + floor(random() * 9000))::int,
    mktsegment = (ARRAY['AUTOMOBILE', 'BUILDING', 'FURNITURE', 'HOUSEHOLD', 'MACHINERY'])
                 [1 + floor(random() * 5)::int]
WHERE custkey IN (
  SELECT custkey FROM oltp.customer WHERE custkey % 3 = 0 ORDER BY random() LIMIT {n}
)
$sql$, '{n}', getvariable('changed_customers')::VARCHAR));

-- 6. Customer delete: only customers with no order, now or in the future (tpch)
CALL postgres_execute('source', replace($sql$
DELETE FROM oltp.customer
WHERE custkey IN (
  SELECT c.custkey FROM oltp.customer c
  WHERE NOT EXISTS (SELECT 1 FROM tpch.orders o WHERE o.o_custkey = c.custkey)
  ORDER BY random() LIMIT {n}
)
$sql$, '{n}', getvariable('deleted_customers')::VARCHAR));

-- 7. Supplier insert: new suppliers (outside the supply chain)
CALL postgres_execute('source', replace($sql$
INSERT INTO oltp.supplier (suppkey, name, address, nationkey, phone, acctbal, comment)
SELECT k, 'Supplier#' || lpad(k::text, 9, '0'), substr(md5(random()::text), 1, 20), nk,
       (10 + nk) || '-' || (100 + floor(random() * 900))::int || '-'
         || (100 + floor(random() * 900))::int || '-' || (1000 + floor(random() * 9000))::int,
       round((random() * 10998.99 - 999.99)::numeric, 2),
       'new supplier'
FROM (SELECT (SELECT max(suppkey) FROM oltp.supplier) + g AS k, floor(random() * 25)::int AS nk
      FROM generate_series(1, {n}) g) x
$sql$, '{n}', getvariable('new_suppliers')::VARCHAR));

-- 8. Supplier update: new address, phone and account balance
CALL postgres_execute('source', replace($sql$
UPDATE oltp.supplier s
SET address = substr(md5(random()::text), 1, 20),
    phone = (10 + s.nationkey) || '-' || (100 + floor(random() * 900))::int
            || '-' || (100 + floor(random() * 900))::int
            || '-' || (1000 + floor(random() * 9000))::int,
    acctbal = round((random() * 10998.99 - 999.99)::numeric, 2)
WHERE suppkey IN (SELECT suppkey FROM oltp.supplier ORDER BY random() LIMIT {n})
$sql$, '{n}', getvariable('changed_suppliers')::VARCHAR));

-- 9. Part-supplier update: new stock and cost
CALL postgres_execute('source', replace($sql$
UPDATE oltp.partsupp
SET availqty = 1 + floor(random() * 9999)::int,
    supplycost = round((1 + random() * 999)::numeric, 2)
WHERE (partkey, suppkey) IN (
  SELECT partkey, suppkey FROM oltp.partsupp ORDER BY random() LIMIT {n}
)
$sql$, '{n}', getvariable('changed_partsupp')::VARCHAR));

-- 10. Part-supplier delete: only pairs no line item uses, now or in the future (tpch)
CALL postgres_execute('source', replace($sql$
DELETE FROM oltp.partsupp
WHERE (partkey, suppkey) IN (
  SELECT ps.partkey, ps.suppkey FROM oltp.partsupp ps
  WHERE NOT EXISTS (SELECT 1 FROM tpch.lineitem l
                    WHERE l.l_partkey = ps.partkey AND l.l_suppkey = ps.suppkey)
  ORDER BY random() LIMIT {n}
)
$sql$, '{n}', getvariable('deleted_partsupp')::VARCHAR));

-- 11. Summary
SELECT max(orderdate) AS simulated_day,
       count(*) FILTER (WHERE orderdate = (SELECT max(orderdate) FROM source.oltp.orders)) AS new_orders,
       count(*) FILTER (WHERE orderstatus = 'O') AS open_orders,
       count(*) FILTER (WHERE orderstatus = 'P') AS partial_orders,
       count(*) FILTER (WHERE orderstatus = 'F') AS finished_orders,
       (SELECT count(*) FROM source.oltp.customer) AS customers,
       (SELECT count(*) FROM source.oltp.supplier) AS suppliers,
       (SELECT count(*) FROM source.oltp.partsupp) AS partsupp
FROM source.oltp.orders;
