# Airflow image for phase 04 (D-063, D-066, D-068 to D-070): the official Airflow 3.4.0 image plus
# the Airbyte provider. Built and pushed from the user's computer (D-055) as
# ghcr.io/andrerosalopes/airflow:3.4.0-airbyte6.2.0.

# Official regular image (Python 3.13), pinned by digest so every rebuild uses the same base (D-069)
FROM apache/airflow:3.4.0@sha256:a8d9d19c563c768b2bc605ef26440f28a9164ea886064e99c599b057432ff572

# Links the ghcr.io package to this repository (its page shows the repository README)
LABEL org.opencontainers.image.source=https://github.com/AndreRosaLopes/2026_eks_for_data

# Airbyte provider, with Airflow pinned and the image's constraints file: the tested set of versions
# for Airflow 3.4.0, which fixes the provider at 6.2.0 and airbyte-api at 1.0.1 (D-070)
RUN pip install --no-cache-dir "apache-airflow==3.4.0" "apache-airflow-providers-airbyte==6.2.0" \
    --constraint "${HOME}/constraints.txt"
