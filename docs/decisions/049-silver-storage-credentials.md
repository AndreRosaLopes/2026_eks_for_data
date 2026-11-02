# D-049 — Storage Credentials for Silver

Status: Accepted
Date: 2026-11-02
Phase: specs/03-processing-spark-iceberg

## Context

Spark writes the Iceberg data files to silver, Polaris ([D-044](044-iceberg-rest-catalog-server.md))
writes each table's metadata file, and DuckDB reads both. Polaris's S3 storage configuration
(`AwsStorageConfigInfo`) supports two models: credential vending, where Polaris obtains short-lived
credentials through STS and hands them to the engine for one table, or `stsUnavailable: true`, which
turns vending off so each engine uses its own credentials. The choice sets which IAM roles step
03.02 creates.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Credential vending: Polaris's IRSA role assumes a silver data role (`roleArn`) through STS and vends temporary credentials, scoped to the table, to Spark and DuckDB | The model of Polaris, Snowflake Open Catalog and AWS S3 Tables; the catalog governs access; least privilege per table; engines hold no standing silver access | Three roles (Spark with bronze read only, Polaris, silver data) and a trust from Polaris to the data role; role chaining limits sessions to 1 hour | None (IAM and STS are free) | IRSA ([D-008](008-pod-aws-identity.md)); Polaris also vends on GCS and Azure |
| B. No vending (`stsUnavailable: true`): Polaris, Spark and DuckDB each get silver permissions in their own IRSA role | Broad standing access on every engine; the catalog does not control storage access | Two roles and one more permission on DuckDB; no role chaining | None | IRSA; identity equivalents on the three clouds |

## Decision

- **Recommended:** A, because it is the best practice the catalog was built for (principle 1); the
  extra role is a one-time cost in Terraform.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Apache Polaris management API spec (`AwsStorageConfigInfo`)](https://github.com/apache/polaris/blob/main/spec/polaris-management-service.yml)
- [AWS IAM: role chaining session duration](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_terms-and-concepts.html#iam-term-role-chaining)
