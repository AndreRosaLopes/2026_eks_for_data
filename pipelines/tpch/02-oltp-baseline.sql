-- 02.05 — OLTP baseline in the source Postgres, schema oltp (D-025, D-026, D-028, D-029).
-- Run with the DuckDB CLI in the pod (D-043). Running it again resets oltp (the simulation restarts from
-- yesterday); tpch is never changed. Each postgres_execute runs one native Postgres statement.

-- TPC-H date that becomes yesterday; later orders stay in tpch for the daily simulation.
-- Valid range: '1992-01-01' (first TPC-H order) to '1998-08-02' (last one, loads everything).
SET VARIABLE cutoff = '1997-12-31';

-- Already attached in the UI; needed in a new DuckDB process
ATTACH IF NOT EXISTS '' AS source (TYPE postgres);

-- 1. Empty schema
CALL postgres_execute('source', 'DROP SCHEMA IF EXISTS oltp CASCADE');
CALL postgres_execute('source', 'CREATE SCHEMA oltp');

-- 2. Reference tables in full, without the TPC-H column prefixes
CALL postgres_execute('source', $sql$
CREATE TABLE oltp.region AS
SELECT r_regionkey AS regionkey, r_name AS name, r_comment AS comment
FROM tpch.region
$sql$);

CALL postgres_execute('source', $sql$
CREATE TABLE oltp.nation AS
SELECT n_nationkey AS nationkey, n_name AS name, n_regionkey AS regionkey, n_comment AS comment
FROM tpch.nation
$sql$);

CALL postgres_execute('source', $sql$
CREATE TABLE oltp.supplier AS
SELECT s_suppkey AS suppkey, s_name AS name, s_address AS address, s_nationkey AS nationkey,
       s_phone AS phone, s_acctbal AS acctbal, s_comment AS comment
FROM tpch.supplier
$sql$);

CALL postgres_execute('source', $sql$
CREATE TABLE oltp.customer AS
SELECT c_custkey AS custkey, c_name AS name, c_address AS address, c_nationkey AS nationkey,
       c_phone AS phone, c_acctbal AS acctbal, c_mktsegment AS mktsegment, c_comment AS comment
FROM tpch.customer
$sql$);

CALL postgres_execute('source', $sql$
CREATE TABLE oltp.part AS
SELECT p_partkey AS partkey, p_name AS name, p_mfgr AS mfgr, p_brand AS brand, p_type AS type,
       p_size AS size, p_container AS container, p_retailprice AS retailprice, p_comment AS comment
FROM tpch.part
$sql$);

CALL postgres_execute('source', $sql$
CREATE TABLE oltp.partsupp AS
SELECT ps_partkey AS partkey, ps_suppkey AS suppkey, ps_availqty AS availqty,
       ps_supplycost AS supplycost, ps_comment AS comment
FROM tpch.partsupp
$sql$);

-- 3. Orders up to the cutoff, dates shifted so the cutoff becomes yesterday (D-025).
--    Orders 30+ days old are closed (F), the last 30 days are open (O) (D-026).
CALL postgres_execute('source', replace($sql$
CREATE TABLE oltp.orders AS
SELECT o_orderkey AS orderkey, o_custkey AS custkey,
       CASE WHEN o_orderdate + ((current_date - 1) - DATE '{cutoff}') <= current_date - 30
            THEN 'F' ELSE 'O' END AS orderstatus,
       o_totalprice AS totalprice,
       o_orderdate + ((current_date - 1) - DATE '{cutoff}') AS orderdate,
       o_orderpriority AS orderpriority, o_clerk AS clerk, o_shippriority AS shippriority,
       o_comment AS comment
FROM tpch.orders
WHERE o_orderdate <= DATE '{cutoff}'
$sql$, '{cutoff}', getvariable('cutoff')));

-- 4. Line items of those orders, same shift; status follows the order
CALL postgres_execute('source', replace($sql$
CREATE TABLE oltp.lineitem AS
SELECT l_orderkey AS orderkey, l_partkey AS partkey, l_suppkey AS suppkey,
       l_linenumber AS linenumber, l_quantity AS quantity, l_extendedprice AS extendedprice,
       l_discount AS discount, l_tax AS tax, l_returnflag AS returnflag,
       o.orderstatus AS linestatus,
       l_shipdate + ((current_date - 1) - DATE '{cutoff}') AS shipdate,
       l_commitdate + ((current_date - 1) - DATE '{cutoff}') AS commitdate,
       l_receiptdate + ((current_date - 1) - DATE '{cutoff}') AS receiptdate,
       l_shipinstruct AS shipinstruct, l_shipmode AS shipmode, l_comment AS comment
FROM tpch.lineitem
JOIN oltp.orders o ON o.orderkey = l_orderkey
$sql$, '{cutoff}', getvariable('cutoff')));

-- 5. Primary keys
CALL postgres_execute('source', 'ALTER TABLE oltp.region ADD PRIMARY KEY (regionkey)');
CALL postgres_execute('source', 'ALTER TABLE oltp.nation ADD PRIMARY KEY (nationkey)');
CALL postgres_execute('source', 'ALTER TABLE oltp.supplier ADD PRIMARY KEY (suppkey)');
CALL postgres_execute('source', 'ALTER TABLE oltp.customer ADD PRIMARY KEY (custkey)');
CALL postgres_execute('source', 'ALTER TABLE oltp.part ADD PRIMARY KEY (partkey)');
CALL postgres_execute('source', 'ALTER TABLE oltp.partsupp ADD PRIMARY KEY (partkey, suppkey)');
CALL postgres_execute('source', 'ALTER TABLE oltp.orders ADD PRIMARY KEY (orderkey)');
CALL postgres_execute('source', 'ALTER TABLE oltp.lineitem ADD PRIMARY KEY (orderkey, linenumber)');

-- 6. Foreign keys, without cascade: deletes are explicit (D-029)
CALL postgres_execute('source', 'ALTER TABLE oltp.nation ADD FOREIGN KEY (regionkey) REFERENCES oltp.region');
CALL postgres_execute('source', 'ALTER TABLE oltp.supplier ADD FOREIGN KEY (nationkey) REFERENCES oltp.nation');
CALL postgres_execute('source', 'ALTER TABLE oltp.customer ADD FOREIGN KEY (nationkey) REFERENCES oltp.nation');
CALL postgres_execute('source', 'ALTER TABLE oltp.partsupp ADD FOREIGN KEY (partkey) REFERENCES oltp.part');
CALL postgres_execute('source', 'ALTER TABLE oltp.partsupp ADD FOREIGN KEY (suppkey) REFERENCES oltp.supplier');
CALL postgres_execute('source', 'ALTER TABLE oltp.orders ADD FOREIGN KEY (custkey) REFERENCES oltp.customer');
CALL postgres_execute('source', 'ALTER TABLE oltp.lineitem ADD FOREIGN KEY (orderkey) REFERENCES oltp.orders');
CALL postgres_execute('source', 'ALTER TABLE oltp.lineitem ADD FOREIGN KEY (partkey, suppkey) REFERENCES oltp.partsupp');

-- 7. updated_at: set on insert by the default, on update by the trigger (D-028)
CALL postgres_execute('source', $sql$
CREATE FUNCTION oltp.set_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END
$$
$sql$);

CALL postgres_execute('source', 'ALTER TABLE oltp.region ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now()');
CALL postgres_execute('source', 'ALTER TABLE oltp.nation ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now()');
CALL postgres_execute('source', 'ALTER TABLE oltp.supplier ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now()');
CALL postgres_execute('source', 'ALTER TABLE oltp.customer ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now()');
CALL postgres_execute('source', 'ALTER TABLE oltp.part ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now()');
CALL postgres_execute('source', 'ALTER TABLE oltp.partsupp ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now()');
CALL postgres_execute('source', 'ALTER TABLE oltp.orders ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now()');
CALL postgres_execute('source', 'ALTER TABLE oltp.lineitem ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now()');

CALL postgres_execute('source', 'CREATE TRIGGER set_updated_at BEFORE UPDATE ON oltp.region FOR EACH ROW EXECUTE FUNCTION oltp.set_updated_at()');
CALL postgres_execute('source', 'CREATE TRIGGER set_updated_at BEFORE UPDATE ON oltp.nation FOR EACH ROW EXECUTE FUNCTION oltp.set_updated_at()');
CALL postgres_execute('source', 'CREATE TRIGGER set_updated_at BEFORE UPDATE ON oltp.supplier FOR EACH ROW EXECUTE FUNCTION oltp.set_updated_at()');
CALL postgres_execute('source', 'CREATE TRIGGER set_updated_at BEFORE UPDATE ON oltp.customer FOR EACH ROW EXECUTE FUNCTION oltp.set_updated_at()');
CALL postgres_execute('source', 'CREATE TRIGGER set_updated_at BEFORE UPDATE ON oltp.part FOR EACH ROW EXECUTE FUNCTION oltp.set_updated_at()');
CALL postgres_execute('source', 'CREATE TRIGGER set_updated_at BEFORE UPDATE ON oltp.partsupp FOR EACH ROW EXECUTE FUNCTION oltp.set_updated_at()');
CALL postgres_execute('source', 'CREATE TRIGGER set_updated_at BEFORE UPDATE ON oltp.orders FOR EACH ROW EXECUTE FUNCTION oltp.set_updated_at()');
CALL postgres_execute('source', 'CREATE TRIGGER set_updated_at BEFORE UPDATE ON oltp.lineitem FOR EACH ROW EXECUTE FUNCTION oltp.set_updated_at()');

-- 8. Let DuckDB see the new tables, then summarize
CALL postgres_clear_cache();

SELECT count(*) AS orders, min(orderdate) AS first_order, max(orderdate) AS last_order,
       count(*) FILTER (WHERE orderstatus = 'O') AS open_orders
FROM source.oltp.orders;
