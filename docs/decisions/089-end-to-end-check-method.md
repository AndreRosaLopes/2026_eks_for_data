# D-089 — How the End-to-End Checks Are Run

Status: Accepted
Date: 2026-11-17
Phase: specs/05-lab-state-persistence

## Context

Step 05.05 proves the phase "Done When": before `down.sh`, a marker row is written in each of the
four databases and the current state is recorded (TPC-H row counts, CDC replication slot, Airbyte
connections, `silver.orders` count, Airflow DAG runs); after `up.sh`, the restored state is compared
with it. The plan leaves open whether these commands become a script in the repository. AWS
Well-Architected REL09-BP04 asks for periodic restore tests that query the restored data, and names
"restoring … outside of an established automated procedure" as an anti-pattern. Phases 01 to 03
wrote their end-to-end checks as numbered steps in the phase `README.md`, with no script.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Script `scripts/verify-lab-state.sh`, with a `before` and an `after` half, kept to repeat the test | Best practice: REL09-BP04 asks for a repeatable, automated restore test | One new file to keep up to date with the platform | Zero | Meets the plan Scope; diverges from the phases 01–03 pattern |
| B. No script: the agent runs the commands; the phase `README.md` lists them | Against best practice: REL09-BP04 names a restore check outside an automated procedure as an anti-pattern | No new file | Zero | Meets the plan Scope and the phases 01–03 pattern |

## Decision

- **Recommended:** A, because it is the best practice (principle 1), at the price of one file
  (principle 2).
- **Chosen:** B
- **Reason:** the user does not plan to repeat the test after this phase, so a kept script adds
  nothing; this does not follow the principle priority order (simplicity over best practice).

## Sources

- [REL09-BP04 Perform periodic recovery of the data to verify backup integrity and processes](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_backing_up_data_periodic_recovery_testing_data.html)
- `specs/01-*/README.md`, `specs/02-*/README.md`, `specs/03-*/README.md`, "End-to-End Verification"
