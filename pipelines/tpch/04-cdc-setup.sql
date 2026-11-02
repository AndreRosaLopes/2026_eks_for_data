-- 02.08 — CDC setup in the source Postgres: publication and replication slot for Airbyte
-- (D-039, D-040). Run with the DuckDB CLI in the pod (D-043), before lab03 and after any baseline
-- rerun. Safe to run again: it drops and recreates both, which fails while Airbyte is connected to
-- the slot. The airbyte user is created by Postgres on its first start (D-036).
-- Each postgres_execute runs one native Postgres statement.

-- Already attached in the UI; needed in a new DuckDB process
ATTACH IF NOT EXISTS '' AS source (TYPE postgres);

-- 1. Updates and deletes carry the primary key in the WAL (every oltp table has one)
CALL postgres_execute('source', 'ALTER TABLE oltp.region REPLICA IDENTITY DEFAULT');
CALL postgres_execute('source', 'ALTER TABLE oltp.nation REPLICA IDENTITY DEFAULT');
CALL postgres_execute('source', 'ALTER TABLE oltp.supplier REPLICA IDENTITY DEFAULT');
CALL postgres_execute('source', 'ALTER TABLE oltp.customer REPLICA IDENTITY DEFAULT');
CALL postgres_execute('source', 'ALTER TABLE oltp.part REPLICA IDENTITY DEFAULT');
CALL postgres_execute('source', 'ALTER TABLE oltp.partsupp REPLICA IDENTITY DEFAULT');
CALL postgres_execute('source', 'ALTER TABLE oltp.orders REPLICA IDENTITY DEFAULT');
CALL postgres_execute('source', 'ALTER TABLE oltp.lineitem REPLICA IDENTITY DEFAULT');

-- 2. Start clean: drop the slot (if any), then the publication
CALL postgres_execute('source', $sql$
SELECT pg_drop_replication_slot(slot_name) FROM pg_replication_slots WHERE slot_name = 'airbyte_slot'
$sql$);
CALL postgres_execute('source', 'DROP PUBLICATION IF EXISTS airbyte_publication');

-- 3. Publication: the tables whose changes Airbyte reads
CALL postgres_execute('source', $sql$
CREATE PUBLICATION airbyte_publication FOR TABLE
  oltp.region, oltp.nation, oltp.supplier, oltp.customer,
  oltp.part, oltp.partsupp, oltp.orders, oltp.lineitem
$sql$);

-- 4. Replication slot: Postgres keeps WAL from here until Airbyte reads it (at most 2GB, D-041)
CALL postgres_execute('source', $sql$
SELECT pg_create_logical_replication_slot('airbyte_slot', 'pgoutput')
$sql$);

-- 5. Summary
FROM postgres_query('source', $sql$
SELECT 'slot' AS object, slot_name AS name, plugin || ', ' || slot_type AS detail
FROM pg_replication_slots
UNION ALL
SELECT 'publication', pubname, schemaname || '.' || tablename
FROM pg_publication_tables
ORDER BY 1, 3
$sql$);
