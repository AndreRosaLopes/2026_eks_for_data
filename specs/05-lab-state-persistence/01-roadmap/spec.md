# 05.01 — Roadmap: Specification

Status: Approved
Phase: [05 — Lab State Between Environments](../plan.md)

## Design

| Component | Configuration | ADR |
|---|---|---|
| README §3, new phase 05 row, "Phase" column | "**Lab state:** Velero keeps the databases and buckets between environments" | [D-076](../../../docs/decisions/076-lab-state-persistence.md) |
| README §3, new phase 05 row, "Initial idea of steps" column | "Persistent data root; snapshot controller and Velero; backup on teardown and restore on bring-up; end to end" | [D-077](../../../docs/decisions/077-persistent-data-root.md), [D-078](../../../docs/decisions/078-velero-installation-and-restore-order.md) |
| Home How to Run, "1. Phases" | New row for phase 05: status "In progress (05.01 done)", links to Run and Verify | — |
| Phase 05 Run page | Created from the template; nothing to run yet | — |
| Phase 05 Verify page | Created from the template; the 05.01 section says it has no manual check | — |

## Files

| File | Change |
|---|---|
| `README.md` | Modify: §3, new phase 05 row |
| `HOW_TO_RUN.md` | Modify: "1. Phases", new phase 05 row |
| `specs/05-lab-state-persistence/HOW_TO_RUN.md` | Create: Run page from the template |
| `specs/05-lab-state-persistence/README.md` | Create: Verify page from the template |
| `specs/05-lab-state-persistence/plan.md` | Modify: step status |

## Verification Plan

No manual check: by the user's decision (every test of this phase is automated and run by the
agent), this documentation-only step skips the "at least one Manual check" rule.

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | Roadmap row added | `grep` the phase 05 row in `README.md` | The steps column lists the four ideas of 05.02 to 05.05 | Pending |
| 2 | Automated | Phase pages linked | Check that the Run and Verify links in the home phase 05 row point to existing files | Both files exist | Pending |

## Teardown

No resource incurs cost.
