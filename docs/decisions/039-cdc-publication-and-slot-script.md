# D-039 — CDC Publication and Slot Script

Status: Accepted
Date: 2026-11-02
Phase: specs/02-transactional-ingestion

## Context

With the Airbyte user created at first start ([D-036](036-airbyte-database-user.md)), CDC still
needs a publication and a replication slot. The publication needs the `oltp` tables, so it exists
only after `02-oltp-baseline.sql`, and a rerun of the baseline drops it. The slot retains all WAL
from its creation until Airbyte reads it; Airbyte advises deleting it when syncing stops.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Separate script `04-cdc-setup.sql` in the DuckDB UI, run before lab03 and after any baseline rerun; it drops and recreates both | The slot exists only when CDC is used | One more script to remember | None | [D-027](027-pipeline-scripts.md) C, [D-029](029-oltp-write-method.md) |
| B. At the end of `02-oltp-baseline.sql` | An unused slot retains WAL every simulated day | Recreated by every baseline automatically | None | Lab02 gets an unused slot |
| C. In the Postgres init script | The slot retains the whole load; the publication is lost on the first baseline | One place | None | Does not work: the publication needs the tables |

## Decision

- **Recommended:** A, because the slot exists only when CDC is used, as Airbyte advises.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Airbyte: Postgres source (CDC setup)](https://docs.airbyte.com/integrations/sources/postgres)
- [Airbyte: Postgres troubleshooting (replication slot disk usage)](https://docs.airbyte.com/integrations/sources/postgres/postgres-troubleshooting)
