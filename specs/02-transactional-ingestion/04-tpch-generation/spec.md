# 02.04 — TPC-H Generation: Specification

Status: Approved
Phase: [02 — Transactional Ingestion](../plan.md)

## Design

One SQL script, `pipelines/tpch/01-generate-tpch.sql`, pasted and run in the DuckDB UI
([D-027](../../../docs/decisions/027-pipeline-scripts.md) C):

1. `ATTACH IF NOT EXISTS '' AS source (TYPE postgres)`: already attached in the UI (no effect); it
   makes the same script work in a new DuckDB process (automated checks).
2. `CALL dbgen(sf = 1)` generates the 8 TPC-H tables in DuckDB memory. The scale factor is the only
   value to edit: 1 or 0.1 ([D-024](../../../docs/decisions/024-tpch-dataset-and-scale.md)).
   `dbgen` has a `catalog` parameter but no `schema` parameter, so it cannot write straight into
   `source.tpch`.
3. For each table (`region`, `nation`, `supplier`, `customer`, `part`, `partsupp`, `orders`,
   `lineitem`): `DROP TABLE IF EXISTS source.tpch.<t>`, `CREATE TABLE source.tpch.<t> AS SELECT *
   FROM memory.<t>`, then `DROP TABLE memory.<t>` to free memory.
4. Rerunning replaces everything, so the script is safe to run again (e.g., to change the scale
   factor).

`tpch` stays exactly as generated (no keys, no date shift); keys, `updated_at` and the shift belong
to `oltp` (step 02.05).

Size: SF1 is about 1.4 GB in Postgres (10 Gi volume) and about 250 MB in DuckDB memory
(`memory_limit` 1.5 GB).

To confirm during implementation: whether `dbgen(sf = ...)` accepts a variable or needs the literal
value; how long SF1 takes to copy.

## Files

| File | Change |
|---|---|
| `pipelines/tpch/01-generate-tpch.sql` | Create: the generation script |
| `specs/02-transactional-ingestion/README.md` | Modify: the 02.04 section |
| `specs/02-transactional-ingestion/plan.md` | Modify: step status |

## Verification Plan

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | Script runs at SF0.1 | Same script with `sf = 0.1`, through `kubectl exec -i deploy/duckdb -- /duckdb` | Ends without errors | Pending |
| 2 | Automated | SF0.1 row counts | `count(*)` of the 8 tables in `source.tpch` | region 5, nation 25, supplier 1,000, customer 15,000, part 20,000, partsupp 80,000, orders 150,000, lineitem about 600,000 | Pending |
| 3 | Automated | Rerun is safe | Run again; count again | Same counts, no duplicates | Pending |
| 4 | Automated | Postgres stays healthy | `kubectl -n postgres get pod` | 0 restarts | Pending |
| 5 | Manual | SF1 through the UI | Paste the script into the DuckDB UI with `sf = 1`, run it, then run the count query from the README | supplier 10,000, customer 150,000, part 200,000, partsupp 800,000, orders 1,500,000, lineitem about 6,000,000 | Pending |

## Teardown

Not applicable on its own: the tables live in the Postgres volume and go with it in phase 01
[Turn Off](../../01-ingestion-airbyte-s3/README.md#turn-off). To empty them, `DROP TABLE` the 8
tables in `source.tpch`.
