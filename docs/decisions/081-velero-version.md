# D-081 — Velero Version

Status: Accepted
Date: 2026-11-17
Phase: specs/05-lab-state-persistence

## Context

The Velero docs list v1.19 as the latest version. The official Helm chart README says it installs
v1.18. The AWS plugin compatible with Velero 1.19 (v1.15) exists only as a release candidate
(`v1.15.0-rc.1`); v1.14.4 is the latest stable plugin and pairs with Velero 1.18. Release dates
are not verified: the GitHub releases page returned an error.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Velero 1.18 (official chart) plus AWS plugin 1.14.4 | Stable, compatible pair | Chart default | Same | Meets all requirements |
| B. Velero 1.19 plus AWS plugin 1.15.0-rc.1 | Pre-release plugin | Overrides the chart's image | Same | Meets all requirements |

## Decision

- **Recommended:** A, because it is the latest stable pair.
- **Chosen:** A
- **Reason:** follows the recommendation. The exact chart and patch versions are pinned in the
  step spec.

## Sources

- [Velero AWS plugin: compatibility table](https://github.com/velero-io/velero-plugin-for-aws)
- [Velero AWS plugin releases](https://github.com/velero-io/velero-plugin-for-aws/releases)
- [Velero Helm chart README](https://github.com/vmware-tanzu/helm-charts/blob/main/charts/velero/README.md)
