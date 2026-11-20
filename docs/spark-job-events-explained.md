# Reading the Kubernetes Events of a Spark Job

The events of one run of the `create-objects` job (2026-11-20), listed with:

```bash
kubectl get events -n spark --sort-by=.firstTimestamp -o custom-columns=TIME:.firstTimestamp,POD:.involvedObject.name,REASON:.reason
```

```text
TIME                   POD                                      REASON
2026-11-20T18:40:52Z   create-objects-driver                    Scheduled
2026-11-20T18:40:53Z   create-objects                           SparkApplicationSubmitted
2026-11-20T18:40:53Z   create-objects-driver                    FailedMount
2026-11-20T18:40:53Z   create-objects-driver                    FailedMount
2026-11-20T18:40:55Z   create-objects-driver                    Pulling
2026-11-20T18:41:32Z   create-objects-driver                    Created
2026-11-20T18:41:32Z   create-objects                           SparkDriverRunning
2026-11-20T18:41:32Z   create-objects-driver                    Started
2026-11-20T18:41:32Z   create-objects-driver                    Pulled
2026-11-20T18:41:41Z   create-objects                           SparkExecutorPending
2026-11-20T18:41:41Z   create-objects-590128a1fa43a1e4-exec-1   FailedScheduling
2026-11-20T18:41:42Z   create-objects-590128a1fa43a1e4-exec-1   Nominated
2026-11-20T18:41:59Z   create-objects-590128a1fa43a1e4-exec-1   FailedScheduling
2026-11-20T18:42:00Z   create-objects-590128a1fa43a1e4-exec-1   Scheduled
2026-11-20T18:42:03Z   create-objects-590128a1fa43a1e4-exec-1   Pulling
2026-11-20T18:42:05Z   create-objects-590128a1fa43a1e4-exec-1   TaintManagerEviction
2026-11-20T18:42:25Z   create-objects                           SparkDriverCompleted
2026-11-20T18:42:34Z   create-objects-590128a1fa43a1e4-exec-1   Pulled
2026-11-20T18:42:35Z   create-objects-590128a1fa43a1e4-exec-1   Started
2026-11-20T18:42:35Z   create-objects-590128a1fa43a1e4-exec-1   Killing
2026-11-20T18:42:35Z   create-objects-590128a1fa43a1e4-exec-1   Created
2026-11-20T18:42:35Z   create-objects                           SparkExecutorRunning
2026-11-20T18:42:40Z   create-objects                           SparkExecutorFailed
```

The **POD** column names the object each event is about:

| Object | What it is | Who writes its events |
|---|---|---|
| `create-objects` | The `SparkApplication` | The Spark Operator |
| `create-objects-driver` | The driver pod | Kubernetes |
| `...-exec-1` | The executor pod | Kubernetes |

## 1. Driver Starting (18:40:52 → 18:41:32)

| Time | Event | Meaning |
|---|---|---|
| 18:40:52 | `Scheduled` (driver) | Kubernetes picked a node with room for the driver |
| 18:40:53 | `SparkApplicationSubmitted` | The Spark Operator submitted the job |
| 18:40:53 | `FailedMount` ×2 (driver) | The pod tried to mount two ConfigMaps that Spark creates for it (`...-driver-podspec-conf-map`, `spark-drv-...-conf-map`) a moment before they existed: "not found". Kubernetes retries, and they mounted a second later. Harmless |
| 18:40:55 → 18:41:32 | `Pulling` → `Pulled`, `Created`, `Started` (driver) | Downloaded the 1.44 GB image (about 37 s), created and started the container |
| 18:41:32 | `SparkDriverRunning` | The Spark Operator sees the driver running |

## 2. Executor Waiting for a Node (18:41:41 → 18:42:05)

| Time | Event | Meaning |
|---|---|---|
| 18:41:41 | `SparkExecutorPending` + `FailedScheduling` (exec) | The driver asked for 1 executor; no node had enough CPU and memory |
| 18:41:42 | `Nominated` (exec) | Karpenter promised a new node for this pod |
| 18:41:59 | `FailedScheduling` (exec), again | The new node had joined but was not ready yet: it still carried a "not ready" taint (a mark that keeps pods off a node) |
| 18:42:00 | `Scheduled` (exec) | The executor got the new node |
| 18:42:03 | `Pulling` (exec) | Downloads the image on that node, which has none in cache |
| 18:42:05 | `TaintManagerEviction` (exec) | "Cancelling deletion of Pod": while the node was marked "not ready", Kubernetes had planned to remove the pod; the node became ready, so it cancelled. Harmless |

## 3. The Driver Finishes Before the Executor Arrives (18:42:25 → 18:42:40)

| Time | Event | Meaning |
|---|---|---|
| 18:42:25 | `SparkDriverCompleted` | The driver created the 8 tables alone and finished: the job succeeded |
| 18:42:34 → 18:42:35 | `Pulled`, `Created`, `Started` (exec) | The executor finished downloading (about 31 s) and started… |
| 18:42:35 | `Killing` (exec) + `SparkExecutorRunning` | …and was stopped at once, because its driver no longer exists |
| 18:42:40 | `SparkExecutorFailed` | The Spark Operator records that the executor ended with an error. A side effect of being killed, not a job failure: the job is `COMPLETED` |

## 4. What Mattered

Two events decided the outcome:

- `SparkDriverCompleted`: the job succeeded.
- The gap between the executor's `FailedScheduling` and `Scheduled`: the time spent waiting for
  Karpenter's new node.

`FailedMount`, `TaintManagerEviction` and `SparkExecutorFailed` look alarming, but they were
transient or side effects.

The driver did not wait for the executor because Spark waits at most 30 s for executors at start-up
(`spark.scheduler.maxRegisteredResourcesWaitingTime`, a Spark default), and this job's work (DDL
calls to Polaris) runs on the driver alone. The full timeline of the run, with the node's creation
and removal, is in the
[create objects lab, step 7](labs/lab_create_objects_in_polaris.md#7-read-the-timeline-of-a-run).
