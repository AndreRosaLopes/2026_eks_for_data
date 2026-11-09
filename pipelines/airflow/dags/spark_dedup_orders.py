"""Runs the Spark dedup job (phase 03) from Airflow (step 04.04).

The job definition is the SparkApplication template in pipelines/spark/dedup-orders.yaml (D-073);
Airflow fills in the catalog, namespace and table from this run's parameters, creates the
SparkApplication in namespace spark and waits for it without holding a pod (D-074).
"""
from datetime import datetime
from pathlib import Path

from airflow.providers.cncf.kubernetes.operators.spark_kubernetes import SparkKubernetesOperator
from airflow.sdk import Param, dag

# pipelines/spark in the Git checkout of the DAG bundle (D-067): this file is in pipelines/airflow/dags
SPARK_JOBS = Path(__file__).resolve().parents[2] / "spark"


@dag(
    schedule=None,
    start_date=datetime(2026, 1, 1),
    catchup=False,
    template_searchpath=[str(SPARK_JOBS)],
    params={
        "catalog": Param(type="string", description="Polaris catalog, chosen in the lab"),
        "namespace": Param(type="string", description="Iceberg namespace"),
        "table": Param(type="string", description="Iceberg table"),
    },
    tags=["spark"],
)
def spark_dedup_orders():
    SparkKubernetesOperator(
        task_id="dedup_orders",
        namespace="spark",
        application_file="dedup-orders.yaml",
        deferrable=True,
    )


spark_dedup_orders()
