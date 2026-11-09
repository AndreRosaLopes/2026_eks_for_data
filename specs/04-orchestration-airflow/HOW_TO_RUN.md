[How to Run](../../HOW_TO_RUN.md) › 04 — Orchestration: Airflow: **Run** | [Verify](README.md)

# 04 — Orchestration: Airflow for Airbyte and Spark: How to Run

What to execute in this phase, once the environment is up. The checks and expected results are in
[Verify](README.md).

## Prerequisites

- The environment up: [How to Run, 3. Bring Up](../../HOW_TO_RUN.md#3-bring-up); Argo CD shows the
  phase services **Synced** and **Healthy**.

## 1. Build and Push the Airflow Image

Builds the Airflow image from [`platform/images/airflow/Dockerfile`](../../platform/images/airflow/Dockerfile)
(the official Airflow 3.4.0 image, pinned by digest, plus the Airbyte provider installed with the
Airflow constraints file) and pushes it to `ghcr.io` ([D-066](../../docs/decisions/066-airbyte-provider-installation.md)).
Needed only when the Dockerfile changes; safe to run again. It needs Docker Desktop running (x86)
and the GitHub CLI (`gh`) logged in with the `write:packages` scope.

1. Add the `write:packages` scope to the `gh` login (once; it opens the browser to approve):

   ```bash
   gh auth refresh -h github.com -s write:packages
   ```

2. Build the image (about 1 minute):

   ```bash
   docker build -t ghcr.io/andrerosalopes/airflow:3.4.0-airbyte6.2.0 platform/images/airflow
   ```

3. Log in to `ghcr.io` with the `gh` token:

   ```bash
   gh auth token | docker login ghcr.io -u andrerosalopes --password-stdin
   ```

4. Push the image:

   ```bash
   docker push ghcr.io/andrerosalopes/airflow:3.4.0-airbyte6.2.0
   ```

5. Only after the first push: make the package public on GitHub (**Your profile** → **Packages** →
   `airflow` → **Package settings** → **Change visibility** → **Public**), so the cluster pulls it
   without credentials ([D-047](../../docs/decisions/047-spark-dependencies.md)).

## 2. Run the Smoke Test DAG

Runs [`smoke_test`](../../pipelines/airflow/dags/smoke_test.py), a DAG with one task that prints a
line. It checks that Airflow reads DAGs from Git, runs each task in its own pod and keeps the task
log in S3. Takes about 1 minute; safe to run again.

1. Open the Airflow UI ([How to Run, 4.8 Airflow](../../HOW_TO_RUN.md#48-airflow)).
2. In **Dags**, open `smoke_test`, turn on its toggle (new DAGs start paused) and click **Trigger**.
3. Open the run, then the task `hello`, then **Logs**.
