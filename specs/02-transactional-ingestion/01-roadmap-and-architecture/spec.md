# 02.01 — Roadmap and Architecture: Specification

Status: Approved
Phase: [02 — Transactional Ingestion](../plan.md)

## Design

The step resolves the two divergences recorded in `plan.md` (principle 7). It only changes
documentation.

1. **README §2 (Target Architecture):** two rows are added after "Ingestion":

   | Layer | Component |
   |---|---|
   | Source database (simulated OLTP) | PostgreSQL |
   | Data generation and exploration | DuckDB |

2. **README §3 (Phases):** phase 02 becomes this phase, and the later phases move down one number:

   | # | Phase | Initial idea of steps |
   |---|---|---|
   | 01 | **Ingestion:** Airbyte writing to AWS S3 | (unchanged) |
   | 02 | **Transactional ingestion:** TPC-H in Postgres, date cursor and CDC | Source Postgres; DuckDB service; data load and day simulation; labs 02 and 03 |
   | 03 | **Processing and transformation:** Trino and dbt | To be defined |
   | 04 | **Orchestration:** Airflow | To be defined |
   | — | **Next phases** | To be decided |

3. **Phase README:** `specs/02-transactional-ingestion/README.md` is created with the structure of
   the phase 01 README (title, Prerequisites, Access, Step Verification), starting with the 02.01
   section. Each later step adds its own section.

No other document needs changing: a search for mentions of the later phases found only README §3,
and D-022 already uses "Phase 02" with the new meaning.

## Files

| File | Change |
|---|---|
| `README.md` | Modify: §2 gets the two rows; §3 renumbers the phases |
| `specs/02-transactional-ingestion/README.md` | Create: phase verification guide with the 02.01 section |
| `specs/02-transactional-ingestion/plan.md` | Modify: step 02.01 status and the "Divergences to resolve" paragraph marked as resolved |

## Verification Plan

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | §2 lists the source database and DuckDB | `grep -nE "PostgreSQL\|DuckDB" README.md` | One row for each | Pending |
| 2 | Automated | §3 has the new numbering | `grep -nE "^\| 0[1-4] \|" README.md` | 01 Ingestion, 02 Transactional ingestion, 03 Trino and dbt, 04 Airflow | Pending |
| 3 | Automated | Relative links in the changed files resolve | Check each `](...)` link in the 3 files against the file system | No broken link | Pending |
| 4 | Manual | The roadmap and architecture match the phase 02 plan | Open `README.md` §2 and §3 next to `specs/02-transactional-ingestion/plan.md` | §2 shows PostgreSQL and DuckDB; §3 shows phase 02 as transactional ingestion and Trino/dbt as 03 | Pending |

## Teardown

Not applicable: no resources are created. To undo, revert the commit.
