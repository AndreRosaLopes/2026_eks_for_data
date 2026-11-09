# D-075 — Short-Lived Pods and Node Consolidation

Status: Accepted
Date: 2026-11-09
Phase: specs/04-orchestration-airflow

## Context

EKS Auto Mode's built-in node pool `general-purpose` consolidates nodes that are empty or
underutilized, 30 seconds after they qualify (`consolidateAfter: 30s`): it moves pods to fewer nodes
and removes the rest. In 04.04 this evicted, mid-run, both an Airflow task pod and a Spark driver
(`Evicted pod: Underutilized`). Built-in node pools cannot be modified. The AWS docs give two ways to
handle this: the pod annotation `karpenter.sh/do-not-disrupt: "true"` keeps the node "as long as the
annotated pod is running on it", to be used "only for workloads where mid-execution disruption causes
data loss or significant rework", at a higher cost; or, for shorter-lived workloads, "allow disruption
and rely on [the] built-in retry logic". The dedup job takes about 3 minutes and replaces the whole
table on every run, so running it again loses nothing.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Airflow task retries (for example 2 retries, 1 minute apart): an evicted task runs again and recreates the job | Best practice: AWS advises allowing disruption and relying on retries for shorter-lived workloads | One setting in the DAG (`retries`) | Consolidation keeps working | Meets D-064 and D-074; the job is safe to rerun |
| B. `karpenter.sh/do-not-disrupt: "true"` on Airflow task pods and on the Spark driver and executors | Accepted practice: AWS reserves it for runs where disruption causes "significant rework" | Annotations in the chart values and in the `SparkApplication` | Nodes with these pods are kept while they run | Meets all requirements |
| C. Both | Accepted practice: B's protection plus A's safety net | Both changes | As B | Meets all requirements |

AKS node auto-provisioning (also Karpenter) offers the same annotation; the AKS Cluster Autoscaler
uses `cluster-autoscaler.kubernetes.io/safe-to-evict: "false"`. The GKE equivalent was not verified.

## Decision

- **Recommended:** A, because it is the practice AWS gives for short workloads and keeps
  consolidation saving money.
- **Chosen:** B
- **Reason:** the user prefers that running jobs are never interrupted, accepting the higher cost;
  it is the pattern AWS gives for long, critical batch jobs. It differs from the recommendation
  (cost set aside for protection). The annotation goes only on short-lived pods (Airflow task pods,
  Spark driver and executors), never on the long-running Airflow components, so their nodes still
  consolidate once the jobs end.

## Sources

- [Amazon EKS: cost optimization in EKS Auto Mode ("What blocks consolidation")](https://docs.aws.amazon.com/eks/latest/userguide/auto-cost-control.html)
- [Amazon EKS: create a node pool for EKS Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/create-node-pool.html)
- [AKS: cluster autoscaler best practices](https://learn.microsoft.com/azure/aks/cluster-autoscaler-overview#best-practices-and-considerations)
- [AKS: node auto-provisioning disruption policies](https://learn.microsoft.com/azure/aks/node-auto-provisioning-disruption)
- Cluster on 2026-11-09: `kubectl get nodepool general-purpose`; events `Evicted pod: Underutilized`
