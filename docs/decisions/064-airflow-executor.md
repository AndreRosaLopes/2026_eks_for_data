# D-064 — Airflow Executor

Status: Accepted
Date: 2026-11-09
Phase: specs/04-orchestration-airflow

## Context

The executor decides where a task runs. Airflow runs on EKS, a cluster of several nodes that Auto
Mode adds and removes. The Airflow docs say: "You can use the `LocalExecutor` for small,
single-machine production installations, or one of the remote executors for a multi-machine/cloud
installation". Remote executors are containerized (KubernetesExecutor: one pod per task, alive only
while it runs) or queued (CeleryExecutor: always-on workers fed by Redis). Per the Kubernetes
provider docs, with the KubernetesExecutor "logs will be lost after the worker pods shut down"
unless logging persistence or remote logging (object storage such as S3, GCS or Azure Blob) is
enabled.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. KubernetesExecutor, with task logs in S3 (remote logging) | Best practice: the Airflow docs recommend a remote executor for a multi-machine/cloud installation, and the provider docs require remote logging to keep logs | A pod per task; one IAM role and an S3 location for the logs | Pods only while tasks run; S3 in cents | IRSA ([D-008](008-pod-aws-identity.md)); Airflow also supports GCS and Azure Blob for logs |
| B. KubernetesExecutor, without remote logging | Against best practice: the provider docs say logs "will be lost after the worker pods shut down" | A pod per task; no logs setup | Pods only while tasks run | Meets all requirements; lost logs make failures hard to diagnose |
| C. CeleryExecutor (the chart default) | Accepted practice: a remote executor; idle workers "can be expensive if your workload is not constant" | Redis and workers to run | Workers always on | Meets all requirements |
| D. LocalExecutor: tasks run in the scheduler pod | Against best practice: the docs reserve it for "single-machine" installations, and EKS is multi-machine | No extra components | Lowest: no task pods | Meets all requirements |

## Decision

- **Recommended:** A, because it is the remote executor designed for Kubernetes, which the docs
  recommend for a cloud installation, and it keeps task logs as the provider docs require; its
  pods exist only while tasks run, so it costs less than C.
- **Chosen:** A
- **Reason:** follows the recommendation. Remote task logs are part of the phase scope; the step
  04.03 spec decides the S3 location and the IAM role.

## Sources

- [Airflow 3.4.0: executors](https://github.com/apache/airflow/blob/3.4.0/airflow-core/docs/core-concepts/executor/index.rst)
- [Kubernetes provider 10.25.0: KubernetesExecutor (managing DAGs and logs)](https://github.com/apache/airflow/blob/providers-cncf-kubernetes/10.25.0/providers/cncf/kubernetes/docs/kubernetes_executor.rst)
- [Airflow 3.4.0: logging for tasks](https://github.com/apache/airflow/blob/3.4.0/airflow-core/docs/administration-and-deployment/logging-monitoring/logging-tasks.rst)
