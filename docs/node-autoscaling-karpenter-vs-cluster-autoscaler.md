# Node Autoscaling: Auto Mode (Karpenter) vs. Cluster Autoscaler

Both are **node autoscalers**: they react to `Pending` pods and size from **requests**, not usage. The
difference is **how** they create and remove machines.

## 1. The Core Difference

- **Cluster Autoscaler** turns a knob on **groups you defined in advance**: "the `spot` group of
  m7g.large has 0 nodes; set it to 1".
- **Karpenter** has no groups: it looks at the waiting pods and **picks the right machine** from a list
  of allowed constraints: "these pods need 3 vCPU / 6 GiB; the cheapest fit is an m7a.xlarge".

## 2. Comparison

| | **Cluster Autoscaler** | **Karpenter / Auto Mode** |
|---|---|---|
| Unit it manages | **Node group** (Auto Scaling Group / managed node group) | **NodePool**: constraints (families, sizes, arch, Spot/on-demand), not fixed machines |
| Instance type | Fixed per group (chosen beforehand) | Chosen at the moment, from dozens of types, to fit the pods (bin packing) |
| How it creates a node | Raises the group's `desired` count; the ASG launches the machine | Calls EC2 directly (no ASG) |
| Speed | Slower (scan + ASG) | Faster (direct launch) |
| Removing nodes | Node below ~50% of requests for ~10 min, and its pods fit elsewhere | **Consolidation:** removes empty nodes **or replaces** them with smaller, cheaper ones |
| Spot | One group per capacity type (e.g., `base` on-demand + `spot`) | Same NodePool can allow Spot and on-demand; prefers Spot when allowed |
| Upfront planning | You design the groups: type, min/max, labels, taints | You declare limits and constraints; machines come out on demand |
| Node lifetime | Indefinite | Nodes expire and are replaced periodically (Auto Mode: max 21 days), keeping the AMI patched |
| Who runs it | You (Helm chart, IAM, version matching Kubernetes) | **Auto Mode:** AWS runs Karpenter, plus the CNI, EBS CSI and load balancer controller |
| Extra cost | None (one pod) | **Auto Mode:** fee of about 12% of the instance price. Open-source Karpenter has no fee, but you run it |
| Access to the node | Full (SSH/SSM, your own AMI) | **Auto Mode:** locked, AWS-managed AMI; no SSH |

## 3. What That Means in Practice

| Situation | Cluster Autoscaler | Auto Mode |
|---|---|---|
| Steady workload with a known size | Works well and costs less (no fee) | Works, with the fee |
| Varied workloads (Airbyte sync, Spark with different executor sizes) | Machines of the group's fixed size, which may waste capacity or not fit | Machine chosen to fit each wave of pods |
| Idle cluster after a job | Waits ~10 min, removes only whole nodes | Removes quickly, and replaces large nodes with smaller ones |
| Operational effort | You maintain the groups, the Cluster Autoscaler, and the add-ons | AWS maintains them |

**Summary:** Cluster Autoscaler is cheaper and gives you more control, but you plan the machines
yourself. Auto Mode costs about 12% more per node, but chooses, consolidates and maintains the
machines for you. That pays off most with varied, short-lived workloads like Spark.

Neither one fixes wrong requests: both make decisions from the same reservations.

## Sources

- [Cluster Autoscaler FAQ](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md)
- [Karpenter: Disruption](https://karpenter.sh/docs/concepts/disruption/)
- [EKS Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)
- [EKS Auto Mode pricing](https://aws.amazon.com/eks/pricing/)
