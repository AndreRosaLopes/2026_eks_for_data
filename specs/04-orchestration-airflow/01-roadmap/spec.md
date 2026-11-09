# 04.01 — Roadmap: Specification

Status: Implemented
Phase: [04 — Orchestration: Airflow for Airbyte and Spark](../plan.md)

## Design

| Component | Configuration | ADR |
|---|---|---|
| README §3, phase 04 row, "Phase" column | Unchanged: "**Orchestration:** Airflow triggering Airbyte and Spark" | — |
| README §3, phase 04 row, "Initial idea of steps" column | "To be defined" → "Airflow image; Airflow with its metadata Postgres and task logs in S3; Spark DAG; Airbyte DAG, end to end" | [D-064](../../../docs/decisions/064-airflow-executor.md), [D-065](../../../docs/decisions/065-airflow-metadata-database.md), [D-066](../../../docs/decisions/066-airbyte-provider-installation.md) |
| Home How to Run, "1. Phases" | New row for phase 04: status "In progress (04.01 done)", links to Run and Verify | — |
| Phase 04 Run page | Created from the template; nothing to run yet | — |
| Phase 04 Verify page | Created from the template; the 04.01 section says it has no manual check | — |

## Files

| File | Change |
|---|---|
| `README.md` | Modify: §3, phase 04 row, steps column |
| `HOW_TO_RUN.md` | Modify: "1. Phases", new phase 04 row |
| `specs/04-orchestration-airflow/HOW_TO_RUN.md` | Create: Run page from the template |
| `specs/04-orchestration-airflow/README.md` | Create: Verify page from the template |
| `specs/04-orchestration-airflow/plan.md` | Modify: step status |

## Verification Plan

No manual check: by the user's decision, this documentation-only step skips the "at least one
Manual check" rule.

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | Roadmap row updated | `grep` the phase 04 row in `README.md` | The steps column lists the four steps of 04.02 to 04.05; no "To be defined" | Pass: row 04 lists "Airflow image; Airflow with its metadata Postgres and task logs in S3; Spark DAG; Airbyte DAG, end to end"; no "To be defined" left in `README.md` |
| 2 | Automated | Phase pages linked | Check that the Run and Verify links in the home phase 04 row point to existing files | Both files exist | Pass: both links resolve to existing files |

## Teardown

No resource incurs cost.
