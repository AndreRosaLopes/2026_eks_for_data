"""Smoke test for the Airflow setup (step 04.03): one task in its own pod, with its log in S3."""
from datetime import datetime

from airflow.sdk import dag, task


@dag(schedule=None, start_date=datetime(2026, 1, 1), catchup=False, tags=["smoke-test"])
def smoke_test():
    @task
    def hello():
        print("smoke test: hello from a KubernetesExecutor task pod")

    hello()


smoke_test()
