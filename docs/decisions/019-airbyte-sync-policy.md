# D-019 — Airbyte Sync Policy in Argo CD

Status: Accepted
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

In the Airbyte chart 2.4.0, several resources are Helm `pre-install` hooks, with the annotation fixed
in the templates (no value turns it off): the `airbyte-admin` ServiceAccount, Role and RoleBinding,
the bundled Postgres (`airbyte-db` StatefulSet and Service), the Secrets, the environment ConfigMap
and the `airbyte-bootloader` pod. Argo CD maps `pre-install` to `PreSync`, runs it on every sync
(it cannot tell install from upgrade) and, with no deletion policy, assumes `BeforeHookCreation`:
these resources are deleted and recreated on every sync. Postgres restarts (its data stays, since a
StatefulSet PVC is not deleted), and the recreated ServiceAccount gets a new UID, which can
invalidate the tokens of running pods until they restart (likely, not confirmed). With `selfHeal`,
any detected drift triggers a sync.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Automated sync with `prune` and `selfHeal` (as the root Application and both reference projects) | Full GitOps, but any drift recreates the database and the ServiceAccount, with a risk of a loop | Same as 01.04 | Same | Meets all requirements |
| B. Automated sync with `prune`, without `selfHeal` | Git changes are applied automatically; drift shows as `OutOfSync` without triggering hooks; hooks run only when Git changes | One line fewer | Same | Meets all requirements; the root Application keeps `selfHeal` (it only manages Applications and the StorageClass) |
| C. Manual sync | The operator chooses when to sync; leaves automated GitOps | One click per change | Same | Departs from the intent of [D-007](007-argo-cd-installation.md) |
| D. Render through Kustomize + Helm, with patches removing the hook annotations | Resources become regular objects; full GitOps | Much more complex: `kustomization.yaml`, patches on about 10 resources, `--enable-helm` in Argo CD (changes 01.04) | Same | Meets all requirements, with more code |

## Decision

- **Recommended:** B, because it keeps automated GitOps for Git changes (principle 1) and avoids the
  recreation loop with one line of configuration (principle 2). Step 01.05 verifies a forced
  re-sync in practice.
- **Chosen:** B
- **Reason:** follows the recommendation.

## Sources

- [Argo CD: Helm hooks](https://github.com/argoproj/argo-cd/blob/v3.5.5/docs/user-guide/helm.md)
- [Argo CD: resource hooks (default `BeforeHookCreation`)](https://github.com/argoproj/argo-cd/blob/v3.5.5/docs/user-guide/resource_hooks.md)
- [Airbyte issue #84287: bootloader with Argo CD](https://github.com/airbytehq/airbyte/issues/84287)
