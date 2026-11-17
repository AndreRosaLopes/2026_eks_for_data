# D-088 — How the Purge Deletes the Backups

Status: Accepted
Date: 2026-11-17
Phase: specs/05-lab-state-persistence

## Context

The purge is the full reset: after it, nothing of the lab is left. It must remove the backup files in
the Velero bucket, the EBS snapshots behind each backup and the five buckets of `infra/aws/data`.
`terraform destroy` on `infra/aws/data` empties and deletes the buckets
([D-082](082-persistent-bucket-deletion.md)) but not the EBS snapshots, which are kept with `Retain`
([D-085](085-volumesnapshotclass-location.md)). Velero deletes a backup's snapshots only while its
server runs, that is, while the cluster is up. Without the cluster, the snapshots can be found by the
tag `eks:eks-cluster-name` = `eks-for-data`, which EKS Auto Mode's managed policy requires on every
snapshot it creates.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. `down.sh --purge`, with the cluster up: `velero backup delete --all` (bucket files and snapshots), today's teardown without the backup step, then destroy `infra/aws/data` | Best practice: the Velero backup reference deletes backups with `velero backup delete`, which removes their snapshots | One flag on an existing script; if the environment is down, `up.sh` first (about 20 minutes) | About US$ 0.20/h while the cluster is up, if it must be brought up | Meets D-080 and D-082 |
| B. New `scripts/purge.sh`, after `down.sh`: `aws ec2 delete-snapshot` for each snapshot tagged `eks:eks-cluster-name=eks-for-data`, then destroy `infra/aws/data` | No official best practice: no Velero or AWS doc covers deleting Velero snapshots outside Velero (checked Velero backup reference and EKS storage docs) | One new script, about 5 lines; runs at once | Zero | Meets D-080 and D-082 |

## Decision

- **Recommended:** A, because it is the documented Velero practice: principle 1 decides over B's
  lower cost (principle 3). A purge is usually decided at the end of a lab, with the cluster still up.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Velero: backup reference, deleting backups](https://velero.io/docs/main/backup-reference/)
- [Velero: CSI support](https://github.com/vmware-tanzu/velero/blob/main/site/content/docs/main/csi.md): on backup deletion, Velero switches its snapshots to `Delete` even with `Retain`
- [AWS managed policy: AmazonEKSBlockStoragePolicy](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEKSBlockStoragePolicy.html): `ec2:CreateSnapshot` requires the request tag `eks:eks-cluster-name`
- [Amazon EKS: create a storage class](https://docs.aws.amazon.com/eks/latest/userguide/create-storage-class.html)
