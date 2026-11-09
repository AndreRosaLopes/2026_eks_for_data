# D-057 — How a Spark Job Run Is Started

Status: Accepted
Date: 2026-11-07
Phase: specs/03-processing-spark-iceberg

## Context

A Spark job is described by a `SparkApplication`, a YAML file in Git
([D-045](045-spark-on-kubernetes.md)). The job runs once, as soon as that object is created in the
cluster; it runs again only when the object is changed, or deleted and created again. A finished job
stays in the cluster, marked `COMPLETED`.

The choice is who creates the object, and so who starts each run. The script reaches the cluster
through Argo CD either way ([D-048](048-spark-job-code-delivery.md)).

On best practice: neither the Kubeflow nor the Argo CD documentation states a rule for one-off job
runs. The Kubeflow docs start a job with `kubectl apply`. For scheduled runs, the standard is an
orchestrator: in phase 04, Airflow creates the object for each run (D-045).

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Argo CD creates the object from Git | GitOps: the cluster mirrors Git; shown in non-official tutorials | A push that changes the job YAML starts a run; to re-run without a change, delete the object and Argo CD recreates it | A run on every push that changes the job | In phase 04 the object must leave Argo CD, because Airflow creates it |
| B. The user creates it with `kubectl apply -f` on the YAML in Git | The method in the Kubeflow docs; runs started on demand, as Airflow will do in phase 04 | A run starts only on the command; to re-run, `kubectl delete`, then `kubectl apply` | Runs only when asked | Nothing changes in phase 04 |

## Decision

- **Recommended:** B, because it is the method in the official docs, a push never starts a run by
  itself, and phase 04 keeps the same model with Airflow in the user's place.
- **Chosen:** B
- **Reason:** follows the recommendation.

## Sources

- [Kubeflow Spark Operator: Getting Started (`kubectl apply -f examples/spark-pi.yaml`)](https://spark.kubeflow.org/en/latest/getting-started/)
- [Spark Operator v2.5.2 `event_filter.go` (a changed spec re-runs the job)](https://github.com/kubeflow/spark-operator/blob/v2.5.2/internal/controller/sparkapplication/event_filter.go)
- Non-official: [OneUptime: Deploy Apache Spark on Kubernetes with Argo CD](https://oneuptime.com/blog/post/2026-02-26-argocd-deploy-apache-spark-kubernetes/view)
