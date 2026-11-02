# D-043 — Pipeline Script Execution

Status: Accepted
Date: 2026-11-02
Phase: specs/02-transactional-ingestion
Supersedes: [D-027](027-pipeline-scripts.md)

## Context

D-027 chose to paste the SQL files of `pipelines/tpch/` into the DuckDB UI. In step 02.06, the
UI ran only part of `03-simulate-day.sql`: steps 1 to 10 never reached Postgres, with no error.
A test cell (`CREATE TABLE`, then `INSERT` into it) failed with "Failed to prepare query" on the
`INSERT` and created nothing: the UI prepares every statement of a cell before running any. The
DuckDB CLI prepares and runs one statement at a time, and ran the same script completely three
times. The DuckDB and MotherDuck docs do not describe how the UI runs a multi-statement cell. The
scripts stay in `pipelines/tpch/` (D-027).

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. DuckDB CLI in the pod: `kubectl -n duckdb exec -i deploy/duckdb -- /duckdb < pipelines/tpch/<script>.sql` | Proven, repeatable behavior | One command, nothing to paste | None | Reuses the DuckDB pod ([D-033](033-duckdb-service-configuration.md)); the UI stays for exploration |
| B. DuckDB UI with each script split into cells (variables, facts, each dimension) | Depends on undocumented UI behavior | Many pastes per run | None | Keeps D-027 C |
| C. Investigate the UI until the cause is proven | — | More time with the environment up | Environment cost while investigating | — |

## Decision

- **Recommended:** A, because it is the only alternative with proven, repeatable behavior, and the
  simplest.
- **Chosen:** A
- **Reason:** follows the recommendation. It applies to every script in `pipelines/tpch/`,
  including `04-cdc-setup.sql` ([D-039](039-cdc-publication-and-slot-script.md)).

## Sources

- [DuckDB: UI extension](https://duckdb.org/docs/2.0/core_extensions/ui.html)
- [MotherDuck: keyboard shortcuts (run cell, run selection)](https://motherduck.com/docs/getting-started/interfaces/motherduck-quick-tour/)
