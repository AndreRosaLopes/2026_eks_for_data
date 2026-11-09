[How to Run](../../HOW_TO_RUN.md) › 04 — Orchestration: Airflow: [Run](HOW_TO_RUN.md) | **Verify**

# 04 — Orchestration: Airflow for Airbyte and Spark: How to Verify

Airflow runs on the cluster and orchestrates the pipeline end to end: one DAG run triggers the
Airbyte sync to bronze, waits for it, then runs the Spark dedup job into the Iceberg table. Each
step below is verified on its own; the end-to-end verification proves the phase
[Done When](plan.md#done-when).

## Prerequisites and Access

- [How to Run, 2. Prerequisites](../../HOW_TO_RUN.md#2-prerequisites)
- [How to Run, 4. Access](../../HOW_TO_RUN.md#4-access): the services this phase uses

## Step Verification

### 04.01 — Roadmap

No manual check: this step only updates the roadmap in [README §3](../../README.md#3-phases)
([spec](01-roadmap/spec.md)).

### 04.02 — Airflow Image

No manual check: the agent ran every check of the [spec](02-airflow-image/spec.md#verification-plan),
including making the package public. To repeat it, follow
[Run, 1. Build and Push the Airflow Image](HOW_TO_RUN.md#1-build-and-push-the-airflow-image).
- Expected result: the push ends with a line `3.4.0-airbyte6.2.0: digest: sha256:...`, and after
  `docker logout ghcr.io` the `docker pull` of the image succeeds without login.

## End-to-End Verification

Written on the last step: walkthrough proving the phase "Done When".

## Teardown

The whole environment: [How to Run, 5. Teardown](../../HOW_TO_RUN.md#5-teardown). Each step's own
teardown is in its spec:

- [04.01 — Roadmap](01-roadmap/spec.md#teardown)
- [04.02 — Airflow Image](02-airflow-image/spec.md#teardown)
