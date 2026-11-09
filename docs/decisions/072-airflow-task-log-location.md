# D-072 — Location of the Airflow Task Logs

Status: Accepted
Date: 2026-11-09
Phase: specs/04-orchestration-airflow

## Context

With the KubernetesExecutor, task logs go to S3 ([D-064](064-airflow-executor.md)). Airflow writes
them under `remote_base_log_folder` (`s3://bucket/path`), using an IAM role through IRSA, as the
Amazon provider docs describe. The project has three buckets: bronze and silver, one per data layer
([D-015](015-data-lake-bucket-layout.md)), and Airbyte's, for its own logs and state
([D-009](009-airbyte-internal-storage.md)). The choice sets what step 04.03 adds in Terraform.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. A new bucket `eks-for-data-airflow-<account>`, with an IRSA role that reads and writes only that bucket | No official best practice: the Amazon provider docs accept any bucket and path (checked: S3 task handler docs) | One bucket and one role in Terraform, like silver in 03.02 | Cents of S3 storage | Same pattern as Airbyte (D-009): one bucket per platform component |
| B. A prefix `airflow/` in the Airbyte bucket, with a role limited to that prefix | No official best practice: same docs | No new bucket; a policy limited to the prefix | Cents of S3 storage | Mixes two components in one bucket; Airbyte's role already reaches the whole bucket |

## Decision

- **Recommended:** A. No source names a best practice, so principles 2 and 3 decide: A costs the
  same, isolates Airflow's logs and permissions, and repeats D-009; B saves one bucket, but Airbyte
  could then read and write Airflow's logs.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Amazon provider 9.39.0: writing logs to Amazon S3 (`remote_base_log_folder`, IRSA)](https://github.com/apache/airflow/blob/providers-amazon/9.39.0/providers/amazon/docs/logging/s3-task-handler.rst)
- `infra/aws/cluster/storage.tf`: existing buckets and roles
