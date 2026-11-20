-- Silver schema and tables (lab 3.01 Silver Contract). Run by create_objects.py, one statement
-- at a time. Safe to run again: IF NOT EXISTS changes nothing that already exists.

CREATE SCHEMA IF NOT EXISTS lake.silver;

CREATE TABLE IF NOT EXISTS lake.silver.region (
  regionkey bigint, name string, comment string,
  updated_at timestamp, _airbyte_extracted_at timestamp, _row_hash string,
  _batch timestamp, _loaded_at timestamp)
USING iceberg PARTITIONED BY (_batch);

CREATE TABLE IF NOT EXISTS lake.silver.nation (
  nationkey bigint, name string, regionkey bigint, comment string,
  updated_at timestamp, _airbyte_extracted_at timestamp, _row_hash string,
  _batch timestamp, _loaded_at timestamp)
USING iceberg PARTITIONED BY (_batch);

CREATE TABLE IF NOT EXISTS lake.silver.supplier (
  suppkey bigint, name string, address string, nationkey bigint, phone string,
  acctbal decimal(15,2), comment string, created_at date,
  name_number int,
  updated_at timestamp, _airbyte_extracted_at timestamp, _row_hash string,
  _batch timestamp, _loaded_at timestamp)
USING iceberg PARTITIONED BY (_batch);

CREATE TABLE IF NOT EXISTS lake.silver.customer (
  custkey bigint, name string, address string, nationkey bigint, phone string,
  acctbal decimal(15,2), mktsegment string, comment string, created_at date,
  name_number int,
  updated_at timestamp, _airbyte_extracted_at timestamp, _row_hash string,
  _batch timestamp, _loaded_at timestamp)
USING iceberg PARTITIONED BY (_batch);

CREATE TABLE IF NOT EXISTS lake.silver.part (
  partkey bigint, name string, mfgr string, brand string, type string, size int,
  container string, retailprice decimal(15,2), comment string,
  updated_at timestamp, _airbyte_extracted_at timestamp, _row_hash string,
  _batch timestamp, _loaded_at timestamp)
USING iceberg PARTITIONED BY (_batch);

CREATE TABLE IF NOT EXISTS lake.silver.partsupp (
  partkey bigint, suppkey bigint, availqty int, supplycost decimal(15,2), comment string,
  updated_at timestamp, _airbyte_extracted_at timestamp, _row_hash string,
  _batch timestamp, _loaded_at timestamp)
USING iceberg PARTITIONED BY (_batch);

CREATE TABLE IF NOT EXISTS lake.silver.orders (
  orderkey bigint, custkey bigint, orderstatus string, totalprice decimal(15,2),
  orderdate date, orderpriority string, clerk string, shippriority int, comment string,
  priority_number int, priority_label string,
  updated_at timestamp, _airbyte_extracted_at timestamp, _row_hash string,
  _batch timestamp, _loaded_at timestamp)
USING iceberg PARTITIONED BY (_batch);

CREATE TABLE IF NOT EXISTS lake.silver.lineitem (
  orderkey bigint, partkey bigint, suppkey bigint, linenumber int,
  quantity decimal(15,2), extendedprice decimal(15,2), discount decimal(15,2),
  tax decimal(15,2), returnflag string, linestatus string, shipdate date, commitdate date,
  receiptdate date, shipinstruct string, shipmode string, comment string,
  updated_at timestamp, _airbyte_extracted_at timestamp, _row_hash string,
  _batch timestamp, _loaded_at timestamp)
USING iceberg PARTITIONED BY (_batch);
