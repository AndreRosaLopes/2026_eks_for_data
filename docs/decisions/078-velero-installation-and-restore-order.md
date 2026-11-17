# D-078 — How Velero Is Installed and When the Restore Runs

Status: Accepted
Date: 2026-11-17
Phase: specs/05-lab-state-persistence

## Context

Velero skips any object that already exists in the cluster. If Argo CD starts the Postgres
StatefulSets first, they create empty PVCs and the restore of the volumes is skipped. So Velero must
be installed, and the restore must finish, before the `gitops` root creates Argo CD's root
Application.
Discarded: **Velero as an Argo CD Application**, because Argo CD syncs the child Applications
together; holding them until a one-time restore finishes would need sync waves plus a custom health
check for Applications, and the backup name changes on every teardown.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. New root `infra/aws/backup` (Velero chart via `helm_release`); `up.sh` order: `cluster` → `backup` → restore → `gitops` | Infrastructure as code with state, no provisioners | One more small root | Same | Installed by Terraform, like Argo CD (D-007) |
| B. `helm_release` in `gitops`, with the restore as a `terraform_data` `local-exec` between Velero and the root Application | HashiCorp calls provisioners a last resort | One root, but backup and restore hidden in Terraform | Same | Meets all requirements; the restore runs outside the scripts |
| C. `helm upgrade --install` from `up.sh`, values in a repository file | Outside Terraform state, the reason D-007 rejected scripts | Simplest | Same | Imperative install, unlike D-007 |

## Decision

- **Recommended:** A, because it keeps Velero in Terraform, like Argo CD (D-007), with a clear order
  and no provisioners.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Velero: restore reference](https://velero.io/docs/main/restore-reference/)
- [Velero Helm chart](https://github.com/vmware-tanzu/helm-charts/blob/main/charts/velero/README.md)
