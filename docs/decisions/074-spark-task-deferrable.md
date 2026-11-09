# D-074 — How the Spark Task Waits for the Job

Status: Accepted
Date: 2026-11-09
Phase: specs/04-orchestration-airflow

## Context

After creating the `SparkApplication`, the Airflow task waits until the job ends (about 2 to 3
minutes for dedup, measured in 03.06). With the KubernetesExecutor
([D-064](064-airflow-executor.md)), each task runs in its own pod, so the waiting itself keeps a pod
running. The Airflow docs describe deferrable operators: when a task has nothing to do but wait, it
"can suspend itself and free up the worker"; the wait moves to the triggerer, an Airflow component
already running since 04.03, and the task resumes in a new pod when the job ends.
`SparkKubernetesOperator` 10.25.0 supports this with `deferrable=True`.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. `deferrable=True`: the task pod ends after creating the job, and the triggerer waits | Best practice: the Airflow docs present deferral as the way to stop idle waiting from holding a worker | One parameter; the task runs in two short pods (start and finish) | No pod held during the wait | Uses the triggerer deployed in 04.03 |
| B. Default: the task pod waits until the job ends | Accepted practice: the operator's default mode | No parameter; one pod for the whole task | One small pod held for about 3 minutes per run | Meets all requirements |

## Decision

- **Recommended:** A, the practice the Airflow docs describe for tasks that mostly wait; the same
  pattern serves the Airbyte sync in 04.05, which can wait much longer. Not verified: the deferrable
  mode with this operator in this setup; 04.04 tests it, and B is the fallback.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Airflow 3.4.0: deferrable operators and triggers](https://github.com/apache/airflow/blob/3.4.0/airflow-core/docs/authoring-and-scheduling/deferring.rst)
- [Kubernetes provider 10.25.0: `spark_kubernetes.py` (`execute` with `deferrable`)](https://github.com/apache/airflow/blob/providers-cncf-kubernetes/10.25.0/providers/cncf/kubernetes/src/airflow/providers/cncf/kubernetes/operators/spark_kubernetes.py)
