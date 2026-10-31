# D-027 — Pipeline Scripts: Location and Execution

Status: Accepted
Date: 2026-10-31
Phase: specs/02-transactional-ingestion

## Context

The scripts generate TPC-H, build the OLTP baseline and simulate days. README §6 tracks data pipeline changes separately from infrastructure. The user wants to run the daily script by hand, so the data grows over time.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. SQL files in `pipelines/tpch/`, run inside the DuckDB pod with `kubectl exec` | Versioned and repeatable | One command per run | None | Reuses the DuckDB pod (D-033) |
| B. Kubernetes Job per run, script in a ConfigMap | Ready for automation | One YAML per run | One pod per run | Meets all requirements |
| C. SQL files in `pipelines/tpch/`, pasted and run by hand in the DuckDB UI | Versioned scripts; runs not recorded | Easiest; nothing to install | None | Uses the UI of D-033; scripts separate from infrastructure (README §6) |

## Decision

- **Recommended:** A, because it runs a versioned script with one command.
- **Chosen:** C
- **Reason:** the user runs the scripts by hand in the DuckDB UI, one day at a time, to watch the data grow; reproducing the runs is not a goal of the lab.
