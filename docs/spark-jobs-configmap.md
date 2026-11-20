# How a Spark Job Gets Its Script: ConfigMap and `kustomization.yaml`

The `SparkApplication` orders the computers. The ConfigMap is how the script and the SQL get onto
them, and `kustomization.yaml` says which files go into the ConfigMap.

## 1. The Problem

Kubernetes creates the Spark pods from the Spark image: Spark is installed, but the job's files
(`create_objects.py`, `create_objects.sql`) are not. They are in Git, in `pipelines/spark`.
Something has to carry them into the pod.

## 2. The Pieces

- **ConfigMap `spark-jobs`:** a small "folder" of text files kept inside Kubernetes. The
  `SparkApplication` mounts it at `/opt/spark/jobs`, so when the pod starts, the script and the SQL
  are there to read.
- **`kustomization.yaml`:** the list of files in `pipelines/spark` that go into that folder. After a
  `git push`, Argo CD reads it and rebuilds the ConfigMap with those files. A file left off the list
  does not reach the pod, and the job fails with "file not found".

| Piece | Role (kitchen analogy) |
|---|---|
| Spark image | The kitchen, with the equipment |
| `SparkApplication` | The order: how many cooks, which recipe to follow |
| ConfigMap | The recipe binder delivered to the kitchen |
| `kustomization.yaml` | The list of recipes that go into the binder |

Without the ConfigMap, every change to a script would mean rebuilding the Spark image, or copying
the files into the pods by hand.

## 3. `kustomization.yaml` Is Not the ConfigMap

| | `kustomization.yaml` | ConfigMap `spark-jobs` |
|---|---|---|
| What it is | A file in Git: the **recipe** | An object inside Kubernetes: the **result** |
| Where it lives | `pipelines/spark/` in the repository | The cluster, namespace `spark` |
| Content | Only the **list** of files and the ConfigMap's name | The **content** of those files (the script and the SQL themselves) |
| Who uses it | Argo CD, after `git push` | The Spark pod, which mounts it as the folder `/opt/spark/jobs` |

Flow: `kustomization.yaml` (list) → Argo CD reads it and **builds** the ConfigMap with the files'
content → the pod reads the ConfigMap.

## 4. The Whole File

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: spark
configMapGenerator:
  - name: spark-jobs
    files:
      - read_bronze_orders.py
      - dedup_orders.py
      - create_objects.py
      - create_objects.sql
generatorOptions:
  disableNameSuffixHash: true
```

| Line | Why it matters |
|---|---|
| `namespace: spark` | Puts the ConfigMap in the namespace where the Spark jobs run |
| `configMapGenerator` → `files` | The list: each file becomes one entry of the ConfigMap, under its own name |
| `disableNameSuffixHash: true` | Without it, Kustomize adds a suffix to the name (`spark-jobs-7h2k9...`); the `SparkApplication` looks for `spark-jobs` exactly and would not find it |

To add a job, add only its files under `files:` and keep the rest of the file.
