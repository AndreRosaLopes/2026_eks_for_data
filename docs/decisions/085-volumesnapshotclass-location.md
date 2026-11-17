# D-085 — Where the VolumeSnapshotClass Is Defined

Status: Accepted
Date: 2026-11-17
Phase: specs/05-lab-state-persistence

## Context

A `VolumeSnapshotClass` is the Kubernetes object that tells the snapshot controller which storage
driver takes a snapshot and what happens to it afterwards. The plan sets its content: driver
`ebs.csi.eks.amazonaws.com` (EKS Auto Mode storage), `deletionPolicy: Retain` (the EBS snapshot
outlives the cluster) and the label `velero.io/csi-volumesnapshot-class: "true"` (Velero picks the
class by it). Its kind is defined by the snapshot add-on ([D-084](084-snapshot-controller-addon-version.md))
in `infra/aws/cluster`, applied before `infra/aws/backup`.
Discarded: **an Argo CD manifest in `platform/aws`**, because the restore runs before Argo CD
([D-078](078-velero-installation-and-restore-order.md)) and whether a restore works without the class
is not verified.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Velero chart `extraObjects`, in the `helm_release` of `infra/aws/backup` | Accepted practice: documented chart value (Velero chart `values.yaml`) | No new provider; created and removed with Velero | Zero | Meets D-077 and D-078 |
| B. `kubernetes_manifest` resource in `infra/aws/backup` | Accepted practice: HashiCorp recommends it for custom resources | Adds the Kubernetes provider; cluster reachable at plan time | Zero | Meets D-077 and D-078 |

## Decision

- **Recommended:** A. Both are accepted practice, so principle 2 (simplicity) decides: no extra
  provider, and the class lives in the release that uses it.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Amazon EKS: deploy a sample stateful workload to EKS Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/sample-storage-workload.html): `VolumeSnapshotClass` with driver `ebs.csi.eks.amazonaws.com`
- [Velero: CSI support](https://github.com/vmware-tanzu/velero/blob/main/site/content/docs/main/csi.md): label `velero.io/csi-volumesnapshot-class: "true"`; on backup deletion, Velero switches its snapshots to `Delete` even with `Retain`
- [Velero Helm chart 12.2.5 `values.yaml`](https://github.com/vmware-tanzu/helm-charts/blob/velero-12.2.5/charts/velero/values.yaml): `extraObjects`
- [Terraform Kubernetes provider: `kubernetes_manifest`](https://github.com/hashicorp/terraform-provider-kubernetes/blob/main/docs/resources/manifest.md): needs API access at plan time; recommended for custom resources
