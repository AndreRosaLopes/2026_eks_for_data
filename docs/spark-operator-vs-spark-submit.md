# Running Spark Jobs: Spark Operator vs. `spark-submit`

Both start Spark jobs on Kubernetes. The difference is **how** a job is described and tracked.
The project uses the operator ([D-045](decisions/045-spark-on-kubernetes.md)).

## 1. What the Spark Operator Is

A program that runs inside the cluster and launches Spark jobs for you, like a restaurant manager:
you hand in an order slip, the manager calls the cook and the helpers, they do the work and go home,
and the manager stays, tracking whether each order succeeded.

- **Order slip:** a short YAML file (`SparkApplication`) in Git.
- **Manager:** the Spark Operator, one small pod, always on.
- **Cook and helpers:** the driver and executor pods, which exist only while the job runs.

The operator still runs `spark-submit` underneath; it builds the command from the YAML.

## 2. Plain `spark-submit`

A terminal or pod with Spark and cluster access runs one long command per job:

```bash
spark-submit --master k8s://https://<eks-api> --deploy-mode cluster \
  --conf spark.kubernetes.namespace=spark \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
  --conf spark.kubernetes.container.image=ghcr.io/<owner>/spark:<tag> \
  --conf spark.executor.instances=2 \
  local:///opt/spark/work-dir/job.py
```

## 3. Comparison

| | `spark-submit` | Spark Operator |
|---|---|---|
| How a job is described | A command typed in a terminal | A YAML file in Git, applied by Argo CD |
| Job status | Only in the driver pod's logs | `kubectl get sparkapplication` shows each job's status |
| Retry on failure | You run it again | Set in the YAML |
| Airflow | Wrapped in a generic pod task | Native `SparkKubernetesOperator` |
| Extra component | None | One small pod, always on |

**Summary:** `spark-submit` is cheaper and has one less component, but jobs live outside Git, with
no tracked status or retries. The operator costs one small pod and makes each job a versioned YAML
file.

## Sources

- [Spark on Kubernetes](https://spark.apache.org/docs/latest/running-on-kubernetes.html)
- [Kubeflow Spark Operator](https://spark.kubeflow.org/en/latest/overview/)
