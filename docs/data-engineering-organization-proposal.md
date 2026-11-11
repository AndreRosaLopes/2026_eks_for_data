# Proposal: Organization for the Data Engineering Team

Status: Proposal (not decided). How the data engineering team organizes the Spark code and the
Airflow DAGs in this repository, following the project layout Databricks recommends.

## 1. The Databricks Layout

Databricks organizes a data engineering project as a bundle (Declarative Automation Bundles,
formerly Databricks Asset Bundles):

| Databricks | What it holds |
|---|---|
| `databricks.yml` | Bundle name, variables (catalog, schema) and targets (`dev`, `prod`) |
| `resources/*.job.yml` | Job definitions in YAML |
| `src/my_package/` | The code, built as a Python wheel (a Python package file) with a `main` entry point |
| `tests/` | Unit tests |
| `pyproject.toml` | Package build and dependencies |

Code and job definitions are deployed together per target (`databricks bundle deploy -t dev`).

## 2. Mapping to This Project

| Databricks | This project | Status |
|---|---|---|
| `src/` package | `pipelines/spark/src/lakehouse/` with `common/` (session, read batch, write batch), `silver/` (per-table specs, the pattern of [lab 3.01 C](labs/lab_transformation_3.01_C.md)) and `gold/` | New |
| `tests/` | `pipelines/spark/tests/` with pytest (Python's test runner) on a local Spark | New |
| `pyproject.toml` | `pipelines/spark/pyproject.toml` | New |
| `resources/*.job.yml` | The `SparkApplication` YAML files in `pipelines/spark/jobs/`, used by Airflow as `application_file` ([D-073](decisions/073-spark-dag-job-definition.md)) | Exists; folder to rename |
| Bundle jobs (orchestration) | `pipelines/airflow/dags/`, read by `GitDagBundle` ([D-067](decisions/067-dag-delivery.md)). One DAG per pipeline, e.g. Airbyte sync → bronze-to-silver per table → gold → checks | Exists |
| Shared Airflow code | `pipelines/airflow/dags/common/`, e.g. a helper that builds the Spark task with the parameters | New |
| `targets` dev/prod | DAG parameters `catalog` and `namespace` ([D-073](decisions/073-spark-dag-job-definition.md)): one namespace per engineer for dev, a fixed namespace for prod | Exists via parameters |
| `bundle deploy` | Git push: Argo CD delivers the Spark code, `GitDagBundle` delivers the DAGs | Exists |

Target layout:

```text
pipelines/
  spark/
    pyproject.toml
    Dockerfile            # jobs image (section 4, alternative B)
    src/lakehouse/
      common/             # session, read batch, write batch
      silver/             # per-table specs and treatments
      gold/
    tests/                # pytest on a local Spark
    jobs/                 # SparkApplication templates
  airflow/
    dags/
      common/             # shared DAG helpers
      <pipeline>.py       # one DAG per pipeline, orchestration only
```

## 3. Team Rules

- Spark code holds all the logic: contracts, treatments, writes.
- DAGs only orchestrate: order, parameters, retries. No transformation code in a DAG.
- Each table's treatment is a function with a unit test.

## 4. Open Decision: How the Package Reaches Spark

[D-048](decisions/048-spark-job-code-delivery.md) delivers the Spark code as ConfigMap `spark-jobs`,
which holds flat files with no sub-folders. A package needs folders, so the delivery must be
decided again.

| Alternative | Best practice | Simplicity | Cost | Consistency |
|---|---|---|---|---|
| A. Keep D-048: flat files in ConfigMap `spark-jobs` | Accepted for small jobs; no versioned build of the code | No build. No sub-folders, so the modules use prefixes (`silver_common.py`) and the package layout above is not possible | None | Unchanged |
| B. Jobs image: GitHub Actions builds the package into an image `spark-jobs:<commit>` on top of the Spark platform image, in `ghcr.io` | Closest to the Databricks wheel: one versioned, immutable artifact (it never changes after the build), tested in CI before it runs | One Dockerfile and one workflow, as for the platform image ([D-047](decisions/047-spark-dependencies.md), [D-055](decisions/055-spark-image-build.md)). Each code change waits for a build (minutes); tests run locally first | Free (public `ghcr.io`) | Supersedes D-048. Keeps pipeline code out of the platform image, which was D-048's objection to image builds. Airflow passes the image tag |
| C. Package zip uploaded to S3 by CI, loaded with `deps.pyFiles` | Common on EMR, Amazon's managed Spark | An upload step and its permissions | Negligible | One bucket per cloud, weaker for the multi-cloud goal ([README §1](../README.md#1-objective)) |

**Recommended:** B. Best practice is the first criterion in [principles](principles.md), and B is the
only option that gives the team a real package with tests and a versioned artifact, like the
Databricks wheel. It reuses the image build the project already has, and it fits the separation of
pipeline changes from infrastructure ([README §6](../README.md#6-change-separation)). Its cost is a
slower edit-to-run loop, which the local unit tests offset.

## 5. Next Step

This changes an accepted decision (D-048) and adds a CI workflow. Decisions are made only in
planning ([README §7](../README.md#7-development-process-sdd)), so the next step is `/sdd-plan` for
this organization: package, tests, jobs image and the folder renames.

## Sources

- [Databricks: bundle project templates](https://docs.databricks.com/aws/en/dev-tools/bundles/templates)
- [Databricks: build a Python wheel file using bundles](https://docs.databricks.com/aws/en/dev-tools/bundles/python-wheel)
- [Databricks: work with tasks in bundles](https://docs.databricks.com/aws/en/dev-tools/bundles/work-tasks)
