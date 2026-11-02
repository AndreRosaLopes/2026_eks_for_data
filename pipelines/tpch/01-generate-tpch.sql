-- 02.04 — TPC-H generation into the source Postgres, schema tpch (D-024, D-043).
-- Run with the DuckDB CLI in the pod (D-043). Safe to run again: it replaces the tables.

-- Scale factor: 1 (about 1.4 GB in Postgres) or 0.1
SET VARIABLE sf = 1;

-- Already attached in the UI; needed in a new DuckDB process
ATTACH IF NOT EXISTS '' AS source (TYPE postgres);

-- 1. Generate the 8 tables in DuckDB memory (dbgen has no schema parameter)
CALL dbgen(sf = getvariable('sf'));

-- 2. Copy them to Postgres, schema tpch, as generated (replaced if they exist)
CREATE OR REPLACE TABLE source.tpch.region AS SELECT * FROM memory.region;
CREATE OR REPLACE TABLE source.tpch.nation AS SELECT * FROM memory.nation;
CREATE OR REPLACE TABLE source.tpch.supplier AS SELECT * FROM memory.supplier;
CREATE OR REPLACE TABLE source.tpch.customer AS SELECT * FROM memory.customer;
CREATE OR REPLACE TABLE source.tpch.part AS SELECT * FROM memory.part;
CREATE OR REPLACE TABLE source.tpch.partsupp AS SELECT * FROM memory.partsupp;
CREATE OR REPLACE TABLE source.tpch.orders AS SELECT * FROM memory.orders;
CREATE OR REPLACE TABLE source.tpch.lineitem AS SELECT * FROM memory.lineitem;

-- 3. Row counts in Postgres (SF1: orders 1,500,000; lineitem about 6,000,000)
SELECT 'region' AS table_name, count(*) AS row_count FROM source.tpch.region
UNION ALL SELECT 'nation', count(*) FROM source.tpch.nation
UNION ALL SELECT 'supplier', count(*) FROM source.tpch.supplier
UNION ALL SELECT 'customer', count(*) FROM source.tpch.customer
UNION ALL SELECT 'part', count(*) FROM source.tpch.part
UNION ALL SELECT 'partsupp', count(*) FROM source.tpch.partsupp
UNION ALL SELECT 'orders', count(*) FROM source.tpch.orders
UNION ALL SELECT 'lineitem', count(*) FROM source.tpch.lineitem;

-- 4. Drop only the temporary copies in DuckDB memory; the Postgres tables stay
DROP TABLE memory.region;
DROP TABLE memory.nation;
DROP TABLE memory.supplier;
DROP TABLE memory.customer;
DROP TABLE memory.part;
DROP TABLE memory.partsupp;
DROP TABLE memory.orders;
DROP TABLE memory.lineitem;
