# D-032 — One Argo CD Application per Component

Status: Accepted
Date: 2026-10-31
Phase: specs/02-transactional-ingestion

## Context

The root Application `platform` syncs every `.yaml` file in `platform/aws`. Airbyte is a Helm chart,
so its file is an `Application` and gets its own entry in Argo CD. The source Postgres (step 02.02)
is plain manifests, so its resources were synced directly by `platform`, mixed with the platform
base (StorageClass) and without their own status, sync and history.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Plain manifests synced directly by `platform` | Works, but mixes services with the platform base | Simplest | None | Meets all requirements |
| B. Own Application per component: manifests in `platform/aws/<component>/`, and `platform/aws/<component>.yaml` is an Application pointing to that folder | Argo CD app-of-apps pattern: one Application per component, its own status, sync and history | One small extra file per component | None | Same on AKS and GKE; Airbyte already follows it |
| C. Package Postgres as a Helm chart (e.g., Bitnami `postgresql`) | Common, but adds a chart and its values for a short manifest | Many values to learn | None | Reopens D-022 |

## Decision

- **Recommended:** B, because it follows the app-of-apps pattern and gives each component its own
  Application, without Helm.
- **Chosen:** B
- **Reason:** follows the recommendation.
- **Applies to:** the source Postgres now and every later component with plain manifests (e.g.,
  DuckDB in step 02.03).

## Sources

- [Argo CD: cluster bootstrapping (app of apps)](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
