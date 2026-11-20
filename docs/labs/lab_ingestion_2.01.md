[Labs](README.md) › 2.01

# Lab 2.01 — TPC-H Generation

## Goal

Generate the TPC-H dataset with DuckDB and write it to the `tpch` schema of the source Postgres.
`tpch` is the untouched copy that labs 2.02 and 2.03 read to build and change the transactional
`oltp` schema.

## Prerequisites

1. The environment up, from the repository root in Git Bash:

   ```bash
   ./scripts/up.sh
   ```

   On a **first time** bring-up the databases start empty. On a **continue** bring-up the
   databases are restored from the last backup, so `tpch` may already be there.

2. Postgres and DuckDB running:

   ```bash
   kubectl -n argocd get applications postgres duckdb
   ```

   Expected: both `Synced` and `Healthy`.

3. The DuckDB UI open, to explore. In a second Git Bash window, leave this loop running:

   ```bash
   while true; do kubectl -n duckdb port-forward deploy/duckdb 4213:4213; sleep 1; done
   ```

   Open `http://localhost:4213`. The local port must be 4213. The tunnel often drops
   (`lost connection to pod`): the loop reconnects it, then reload the page. Stop it with `Ctrl+C`
   twice.

## Concepts

- **TPC-H:** a standard benchmark dataset of a wholesale business: regions, nations, suppliers,
  customers, parts, part-supplier pairs, orders and line items (8 tables). Its dates fall between
  1992 and 1998.
- **Scale factor (SF):** the size of the dataset. SF 1 has 1,500,000 orders and about 6,000,000
  line items, about 1.4 GB in Postgres. The project uses SF 1
  ([D-024](../decisions/024-tpch-dataset-and-scale.md)).
- **`dbgen`:** the TPC-H generator. DuckDB has it built in as `CALL dbgen(sf = 1)`, which creates
  the 8 tables in DuckDB's memory.
- **DuckDB attached to Postgres:** `ATTACH '' AS source (TYPE postgres)` makes the source Postgres
  database appear inside DuckDB as `source`, so `source.tpch.orders` is the Postgres table
  `tpch.orders`. The connection details come from the pod's environment variables, so the command
  has no host or password.
- **Where the script runs:** inside the DuckDB pod, with the DuckDB command-line program (CLI),
  fed by `kubectl exec`. The CLI runs one statement at a time; the DuckDB UI is only for exploring
  ([D-043](../decisions/043-pipeline-script-execution.md)).
- **`MSYS_NO_PATHCONV=1`:** stops Git Bash from rewriting `/duckdb`, the program's path in the
  pod, into a Windows path.

## Steps

### 1. Read the Script

Open `pipelines/tpch/01-generate-tpch.sql`. It has four parts:

1. `SET VARIABLE sf = 1;`: the scale factor. Keep it at 1.
2. `CALL dbgen(...)`: generates the 8 tables in DuckDB's memory.
3. `CREATE OR REPLACE TABLE source.tpch.<table> AS SELECT * FROM memory.<table>`: copies each
   table to Postgres, replacing it if it exists.
4. The row count of each table in Postgres, then `DROP TABLE memory.<table>` to free DuckDB's
   memory. The Postgres tables stay.

### 2. Run It

From the repository root in Git Bash (about 1 minute):

```bash
MSYS_NO_PATHCONV=1 kubectl -n duckdb exec -i deploy/duckdb -- /duckdb < pipelines/tpch/01-generate-tpch.sql
```

Expected: no errors, and the script ends with this table:

| Table | Rows |
|---|---|
| `region` | 5 |
| `nation` | 25 |
| `supplier` | 10,000 |
| `customer` | 150,000 |
| `part` | 200,000 |
| `partsupp` | 800,000 |
| `orders` | 1,500,000 |
| `lineitem` | 6,001,215 |

## Validation

In the DuckDB UI, run each query in its own cell.

1. The 8 tables exist in Postgres:

   ```sql
   SELECT table_name FROM source.information_schema.tables
   WHERE table_schema = 'tpch' ORDER BY table_name;
   ```

   Expected: `customer`, `lineitem`, `nation`, `orders`, `part`, `partsupp`, `region`, `supplier`.

2. The TPC-H date range:

   ```sql
   SELECT min(o_orderdate) AS first_order, max(o_orderdate) AS last_order, count(*) AS orders
   FROM source.tpch.orders;
   ```

   Expected: `1992-01-01`, `1998-08-02`, `1500000`.

3. Every column has the TPC-H table prefix (`o_` for orders, `l_` for line items, `c_` for
   customers):

   ```sql
   DESCRIBE source.tpch.orders;
   ```

   Expected: `o_orderkey`, `o_custkey`, `o_orderstatus`, …, `o_comment`.

## Questions

1. Why does the script copy the tables to Postgres instead of leaving them in DuckDB's memory?
2. What happens to `tpch` if you run the script twice?
3. Why does `tpch` keep the original 1992–1998 dates, while `oltp` (lab 2.02) shifts them?
4. Why run the script with the CLI in the pod instead of pasting it into the DuckDB UI?

## Cleanup

Nothing to clean: `tpch` is read by labs 2.02 and 2.03. Running the script again replaces the 8
tables with the same data.
