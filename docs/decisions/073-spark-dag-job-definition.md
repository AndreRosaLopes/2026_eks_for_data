# D-073 — How the Spark DAG Gets the Job Definition

Status: Accepted
Date: 2026-11-09
Phase: specs/04-orchestration-airflow

## Context

The dedup job is defined in `pipelines/spark/dedup-orders.yaml`, whose catalog, namespace and table
arguments are placeholders (`<catalog>`) filled in by hand before `kubectl apply`
([D-057](057-spark-job-run-start.md)). In this phase, Airflow's `SparkKubernetesOperator` creates the
`SparkApplication` and must fill those three names from the DAG run's parameters. It accepts the
definition as `application_file` (a YAML file processed as a template, so `{{ params.catalog }}` is
replaced by the run's parameter) or as `template_spec` (a dictionary built in the DAG's Python code).
`GitDagBundle` ([D-067](067-dag-delivery.md)) checks out the whole repository, so the YAML is
available to the DAG at run time.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. The YAML's placeholders become `{{ params.catalog }}`, `{{ params.namespace }}` and `{{ params.table }}`; the DAG points `application_file` at it | Best practice: the form shown in the provider docs | One file to edit; no extra code | None | One definition (AGENTS.md §1.8); the manual `kubectl apply` of phase 03 §6 needs the names filled in with a command (for example `sed`) |
| B. The YAML keeps `<catalog>`; the DAG reads it in Python, replaces the arguments and passes it as `template_spec` | Accepted practice: `template_spec` is the documented alternative to a file | About 10 lines of Python in the DAG | None | One definition; the manual `kubectl apply` of phase 03 §6 keeps working as today |
| C. The `SparkApplication` written inside the DAG as a dictionary | Accepted practice: `template_spec`, as in B | Self-contained DAG | None | The job would be defined twice, in the YAML and in the DAG (against AGENTS.md §1.8) |

## Decision

- **Recommended:** A, the form in the provider docs; D-057 already foresaw that Airflow would start
  the runs in phase 04. Its only cost is the change to phase 03 How to Run §6.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Kubernetes provider 10.25.0: `SparkKubernetesOperator` docs](https://github.com/apache/airflow/blob/providers-cncf-kubernetes/10.25.0/providers/cncf/kubernetes/docs/operators.rst)
- [Kubernetes provider 10.25.0: `spark_kubernetes.py` (templated fields; a plain `SparkApplication` is accepted)](https://github.com/apache/airflow/blob/providers-cncf-kubernetes/10.25.0/providers/cncf/kubernetes/src/airflow/providers/cncf/kubernetes/operators/spark_kubernetes.py)
