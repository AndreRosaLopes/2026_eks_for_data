# D-056 — Spark Namespace Layout

Status: Accepted
Date: 2026-11-07
Phase: specs/03-processing-spark-iceberg

## Context

Step 03.04 installs the Spark Operator ([D-045](045-spark-on-kubernetes.md)), which watches
`SparkApplication` objects and starts each job's driver and executor pods. A namespace is a named
partition of the cluster. The choice is which namespace holds the operator and which holds the jobs;
it sets the chart values and the Argo CD Application destination. Facts that set the alternatives
apart:

- The operator handles only `SparkApplication` objects in the namespaces listed in the chart value
  `spark.jobNamespaces`. In each, the chart creates the jobs' ServiceAccount (pod identity) and RBAC
  (permissions to create executor pods). These namespaces must already exist.
- The Spark IRSA role of step 03.02 trusts only ServiceAccount `spark` in namespace `spark`.
- The official install puts the operator in its own namespace, `spark-operator`.

Discarded: jobs in `default` (the chart default), because the 03.02 trust requires namespace `spark`.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Operator in `spark-operator`, jobs in `spark` | Official install layout; operator permissions apart from the jobs' | `spark` must exist before the operator syncs: one extra Namespace manifest | None | Meets the 03.02 trust, D-032 and D-045; same on AKS and GKE |
| B. Operator and jobs both in `spark` | Departs from the official layout; jobs share the operator's namespace | One namespace created by Argo CD (`CreateNamespace=true`); nothing to order | None | Meets the 03.02 trust, D-032 and D-045; same on AKS and GKE |

## Decision

- **Recommended:** A, because it is the official layout (principle 1), at the cost of one Namespace
  manifest more than B.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Kubeflow Spark Operator: Getting Started (install namespace, `spark.jobNamespaces`)](https://spark.kubeflow.org/en/latest/getting-started/)
- [Spark Operator v2.5.2 chart `values.yaml`](https://github.com/kubeflow/spark-operator/blob/v2.5.2/charts/spark-operator-chart/values.yaml)
- [Spark Operator releases](https://github.com/kubeflow/spark-operator/releases) (v2.5.2 is the latest stable)
