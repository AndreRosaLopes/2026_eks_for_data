# D-076 — How Lab State Survives Teardown

Status: Accepted
Date: 2026-11-17
Phase: specs/05-lab-state-persistence

## Context

`down.sh` deletes the four database volumes (source Postgres, Polaris catalog Postgres, Airflow
Postgres, Airbyte database) and the buckets, so every new environment starts from zero. The state
must be kept as a whole: the Polaris catalog points to files in silver, and the CDC replication slot
must match the position Airbyte saved.
Discarded: **`pg_dump` to S3**, because a logical dump does not include replication slots.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Pause: keep EKS and the NAT Gateways, delete only the compute | Weak: the cluster becomes long-lived | Simplest | About US$ 0.20/h idle (EKS plus NAT, `HOW_TO_RUN.md` §5.1) | Meets all requirements |
| B. Scripted EBS snapshots (AWS CLI in the scripts) | Good: data lives outside the cluster lifecycle | Medium: custom snapshot and restore logic | Snapshots at US$ 0.05/GB-month: about US$ 0.70/month at most | Partly: new scripts per cloud |
| C. Velero with CSI snapshots | Market standard for Kubernetes backup; AKS docs recommend "Velero or Azure Backup" | Medium: Velero plus the snapshot controller add-on | Same as B | Velero has AWS, Azure and GCP plugins (GCP not verified: the Google docs server failed) |
| D. Velero with CSI snapshot data movement to S3 | Best for disaster recovery: backup outside the primary storage, portable across regions and clouds | Lower: adds the node agent and a Kopia repository; slower restore | S3 at US$ 0.023/GB-month, plus longer restore time | Meets all requirements |

## Decision

- **Recommended:** C, because it is the standard tool for this case, simpler and faster to restore
  than D, whose cross-region portability the project does not need.
- **Chosen:** C
- **Reason:** follows the recommendation.

## Sources

- [Amazon EKS: enable snapshot functionality for CSI volumes](https://docs.aws.amazon.com/eks/latest/userguide/csi-snapshot-controller.html)
- [Amazon EKS: deploy a sample stateful workload to EKS Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/sample-storage-workload.html)
- [Velero: CSI support](https://velero.io/docs/main/csi/)
- [Velero: CSI snapshot data movement](https://velero.io/docs/main/csi-snapshot-data-movement/)
- [AKS: best practices for storage and backups](https://learn.microsoft.com/azure/aks/operator-best-practices-storage#secure-and-back-up-your-data)
- AWS Pricing API (`aws-mcp`), us-east-1: `EBS:SnapshotUsage` US$ 0.05/GB-month; S3
  `TimedStorage-ByteHrs` US$ 0.023/GB-month
