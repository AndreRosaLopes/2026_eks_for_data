# D-045 — How Spark Runs

Status: Accepted
Date: 2026-11-02
Phase: specs/03-processing-spark-iceberg

## Context

Spark runs jobs on EKS: first a read of bronze, then the deduplication into Iceberg, and from
phase 04 on, triggered by Airflow. Each job needs a driver pod and executor pods. The choice is who
creates those pods and how a job is described.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Kubeflow Spark Operator v2.5.2 (Spark 4.0.4 image), Helm via Argo CD; each job a `SparkApplication` YAML in Git | Market standard for Spark on Kubernetes; declarative jobs with status and retries; Airflow submits it natively (`SparkKubernetesOperator`) | One more component (operator and CRD); a job is a short YAML | One small operator pod always on; driver and executors only while a job runs | GitOps ([D-007](007-argo-cd-installation.md), [D-032](032-one-application-per-component.md)); same chart on AKS and GKE |
| B. Plain `spark-submit` against the Kubernetes API, from a pod | Official Spark feature; imperative command lines; status only in pod logs | No operator, but ServiceAccount, RBAC and long commands by hand | Cheapest: nothing always on | Portable; Airflow would wrap it in `KubernetesPodOperator` |
| C. Always-on standalone cluster (master and workers) | Pre-Kubernetes pattern; no isolation between jobs | A cluster to size and operate | Workers idle all day (principle 3) | Bitnami charts no longer publish free images |

## Decision

- **Recommended:** A, because it wins on best practices, simplicity per job and Airflow
  integration; it costs only one small pod more than B.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Kubeflow Spark Operator](https://github.com/kubeflow/spark-operator) and [release v2.5.2](https://github.com/kubeflow/spark-operator/releases/tag/v2.5.2)
- [Apache Spark: Running on Kubernetes](https://spark.apache.org/docs/latest/running-on-kubernetes.html)
