# 05.03 — Snapshot Controller and Velero: Specification

Status: Implemented
Phase: [05 — Lab State Between Environments](../plan.md)

## Design

| Component | Configuration | ADR |
|---|---|---|
| `snapshot-controller` EKS add-on | In `infra/aws/cluster`, version `v8.7.0-eksbuild.4` | [D-084](../../../docs/decisions/084-snapshot-controller-addon-version.md) |
| Velero IRSA role | `eks-for-data-velero`, in `infra/aws/cluster` | [D-008](../../../docs/decisions/008-pod-aws-identity.md), [D-077](../../../docs/decisions/077-persistent-data-root.md) |
| Velero IRSA role | Trusts the ServiceAccount `velero:velero` only | [D-008](../../../docs/decisions/008-pod-aws-identity.md) |
| Velero IRSA role | S3 actions from the AWS plugin README, Velero bucket only; no EC2 actions | [D-076](../../../docs/decisions/076-lab-state-persistence.md) |
| Terraform root `infra/aws/backup` | New root with local state; finds the cluster by name, like `gitops` | [D-078](../../../docs/decisions/078-velero-installation-and-restore-order.md), [D-002](../../../docs/decisions/002-terraform-state-backend.md) |
| Velero | Official chart 12.2.5 (Velero 1.18.2), `helm_release`, namespace `velero` | [D-078](../../../docs/decisions/078-velero-installation-and-restore-order.md), [D-081](../../../docs/decisions/081-velero-version.md) |
| Velero AWS plugin | `velero/velero-plugin-for-aws:v1.14.4` | [D-081](../../../docs/decisions/081-velero-version.md) |
| Backup storage location | Bucket `eks-for-data-velero-<account>`, `us-east-1` | [D-077](../../../docs/decisions/077-persistent-data-root.md) |
| Velero credentials | IRSA annotation on the ServiceAccount; no Secret | [D-008](../../../docs/decisions/008-pod-aws-identity.md) |
| Velero snapshots | `EnableCSI` feature on | [D-076](../../../docs/decisions/076-lab-state-persistence.md) |
| Velero snapshots | Native EBS snapshotter off (`snapshotsEnabled: false`) | [D-076](../../../docs/decisions/076-lab-state-persistence.md) |
| Velero snapshots | Node agent off (no data movement) | [D-076](../../../docs/decisions/076-lab-state-persistence.md) |
| `VolumeSnapshotClass` | In the chart's `extraObjects` | [D-085](../../../docs/decisions/085-volumesnapshotclass-location.md) |
| `VolumeSnapshotClass` | Driver `ebs.csi.eks.amazonaws.com` | [D-085](../../../docs/decisions/085-volumesnapshotclass-location.md) |
| `VolumeSnapshotClass` | `deletionPolicy: Retain` | [D-076](../../../docs/decisions/076-lab-state-persistence.md) |
| `VolumeSnapshotClass` | Label `velero.io/csi-volumesnapshot-class: "true"` | [D-085](../../../docs/decisions/085-volumesnapshotclass-location.md) |
| `up.sh` | Applies `infra/aws/backup` after `cluster`, before `gitops` | [D-078](../../../docs/decisions/078-velero-installation-and-restore-order.md) |
| `down.sh` | Destroys `infra/aws/backup` after `gitops`, before `cluster` | [D-077](../../../docs/decisions/077-persistent-data-root.md) |

## Files

| File | Change |
|---|---|
| `infra/aws/cluster/eks.tf` | Modify: add the pinned `snapshot-controller` add-on |
| `infra/aws/cluster/storage.tf` | Modify: add the Velero IRSA role; the Velero bucket ARN is built from the name pattern |
| `infra/aws/backup/providers.tf` | Create: AWS and Helm providers; cluster found by name |
| `infra/aws/backup/velero.tf` | Create: the Velero `helm_release`, with the `VolumeSnapshotClass` |
| `scripts/up.sh` | Modify: apply `infra/aws/backup` between `cluster` and `gitops` |
| `scripts/down.sh` | Modify: destroy `infra/aws/backup` between `gitops` and `cluster` |

## Verification Plan

No manual check: by the user's decision, every test of this phase is automated and run by the agent
(plan, Scope). This step skips the "at least one Manual check" rule.

Checks 2 to 9 need a running environment: by the user's decision, they run in step 05.05, within
its `down.sh` and `up.sh` cycle, and their results are recorded here.

The test volume is a PVC (a request for an EBS disk) in a throwaway namespace `velero-test`,
holding a marker file.

| # | Type | Check | Command or Action | Expected Result | Result |
|---|---|---|---|---|---|
| 1 | Automated | Both roots are valid | `terraform validate` and `terraform fmt -check` on `cluster` and `backup` | Both valid, no format changes | Pass: both `Success! The configuration is valid.`; `terraform fmt -check` clean |
| 2 | Automated | Bring-up installs the add-on | `up.sh`, then `aws eks describe-addon` for `snapshot-controller` | `ACTIVE`, `v8.7.0-eksbuild.4` | Deferred to 05.05 |
| 3 | Automated | The role is limited to S3 | Read the policies of `eks-for-data-velero` | Only `s3:` actions; only the Velero bucket | Deferred to 05.05 |
| 4 | Automated | Bring-up installs Velero, and it reaches its bucket | `kubectl -n velero get backupstoragelocation` | `Available` | Deferred to 05.05 |
| 5 | Automated | The class exists as specified | `kubectl get volumesnapshotclass -o yaml` | Driver, `Retain` and label as in Design | Deferred to 05.05 |
| 6 | Automated | A volume with no pod attached is backed up (open point of D-079) | Write the marker, delete the pod, create a Velero `Backup` of `velero-test` | Backup `Completed`; the VolumeSnapshot is ready; an EBS snapshot exists | Deferred to 05.05 |
| 7 | Automated | The volume is restored | Delete `velero-test`, create a Velero `Restore`, read the marker from a new pod | Restore `Completed`; marker read | Deferred to 05.05 |
| 8 | Automated | Deleting the backup leaves no snapshot | Delete the test `Backup`, then list the EBS snapshots of the test volume | Empty list | Deferred to 05.05 |
| 9 | Automated | Teardown removes Velero and the cluster | `down.sh`, then `terraform state list` on `backup` and the `down.sh` final lists | Empty state; every list empty | Deferred to 05.05 |

## Teardown

- Test data: delete the `velero-test` namespace and the test `Backup` (check 8).
- Velero and the cluster: `./scripts/down.sh`.
