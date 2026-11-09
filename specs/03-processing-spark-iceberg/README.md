[How to Run](../../HOW_TO_RUN.md) › 03 — Processing: Spark and Iceberg: [Run](HOW_TO_RUN.md) | **Verify**

# 03 — Processing: Spark and Iceberg: How to Verify

Spark on the cluster reads the bronze Parquet files, deduplicates `orders` and writes an Iceberg table
to the silver bucket, registered in the Polaris REST catalog; DuckDB reads it back. Each step below is
verified on its own; the end-to-end verification proves the phase [Done When](plan.md#done-when).

## Prerequisites and Access

- [How to Run, 2. Prerequisites](../../HOW_TO_RUN.md#2-prerequisites)
- [How to Run, 4. Access](../../HOW_TO_RUN.md#4-access)

Run every command in Git Bash, from the repository root, one block at a time.

## Step Verification

### 03.02 — Silver Bucket and IRSA Roles

1. Load `.env`, then preview the Terraform changes.

   ```bash
   set -a; source .env; set +a
   ```

   ```bash
   terraform -chdir=infra/aws/cluster plan -out=tfplan
   ```

   - Expected result: `Plan: 11 to add, 0 to change, 0 to destroy.` Lines saying `has changed` only
     report differences already in AWS (the bucket contents) and change nothing.

2. Apply the plan.

   ```bash
   terraform -chdir=infra/aws/cluster apply tfplan
   ```

   - Expected result: `Apply complete! Resources: 11 added, 0 changed, 0 destroyed.`, and the
     outputs `silver_bucket`, `spark_role_arn`, `polaris_role_arn` and `silver_data_role_arn`.

3. Check the silver bucket: versioning, then the bucket policy.

   ```bash
   aws s3api get-bucket-versioning --bucket eks-for-data-silver-283429977024 --profile eks-ws --region us-east-1
   ```

   - Expected result: no output (versioning was never enabled).

   ```bash
   aws s3api get-bucket-policy --bucket eks-for-data-silver-283429977024 --query Policy --output text --profile eks-ws --region us-east-1
   ```

   - Expected result: a policy with `"Effect":"Deny"` and `"aws:SecureTransport":"false"`.

4. Test the Spark role: a temporary pod with the Spark ServiceAccount reads bronze but cannot write to
   silver. Create the namespace, the ServiceAccount and its role annotation:

   ```bash
   kubectl create namespace spark
   ```

   ```bash
   kubectl -n spark create serviceaccount spark
   ```

   ```bash
   kubectl -n spark annotate serviceaccount spark eks.amazonaws.com/role-arn=arn:aws:iam::283429977024:role/eks-for-data-spark
   ```

   - Expected result: `namespace/spark created`, `serviceaccount/spark created`,
     `serviceaccount/spark annotated`.

   List bronze:

   ```bash
   kubectl -n spark run s3-read --rm -i --restart=Never --image=public.ecr.aws/aws-cli/aws-cli:2.38.1 --overrides='{"spec":{"serviceAccountName":"spark"}}' -- s3 ls s3://eks-for-data-bronze-283429977024/
   ```

   - Expected result: the bronze folders, e.g. `PRE oltp_cursor/`.

   Try to write to silver:

   ```bash
   kubectl -n spark run s3-write --rm -i --restart=Never --image=public.ecr.aws/aws-cli/aws-cli:2.38.1 --overrides='{"spec":{"serviceAccountName":"spark"}}' -- s3api put-object --bucket eks-for-data-silver-283429977024 --key test.txt
   ```

   - Expected result: `An error occurred (AccessDenied)`: Spark has no standing access to silver
     ([D-049](../../docs/decisions/049-silver-storage-credentials.md)).

   Delete the test namespace:

   ```bash
   kubectl delete namespace spark
   ```

   - Expected result: `namespace "spark" deleted`.

5. Test the role chain: a temporary pod with the Polaris ServiceAccount assumes the silver data role,
   then writes and deletes a test object in silver. Create the namespace, the ServiceAccount and its
   role annotation:

   ```bash
   kubectl create namespace polaris
   ```

   ```bash
   kubectl -n polaris create serviceaccount polaris
   ```

   ```bash
   kubectl -n polaris annotate serviceaccount polaris eks.amazonaws.com/role-arn=arn:aws:iam::283429977024:role/eks-for-data-polaris
   ```

   - Expected result: `namespace/polaris created`, `serviceaccount/polaris created`,
     `serviceaccount/polaris annotated`.

   Assume the role, then put and delete the object (one command; it prints no credentials):

   ```bash
   kubectl -n polaris run role-chain --rm -i --restart=Never --image=public.ecr.aws/aws-cli/aws-cli:2.38.1 --overrides='{"spec":{"serviceAccountName":"polaris"}}' --command -- sh -c 'set -- $(aws sts assume-role --role-arn arn:aws:iam::283429977024:role/eks-for-data-silver-data --role-session-name test --query Credentials --output text) && export AWS_ACCESS_KEY_ID=$1 AWS_SECRET_ACCESS_KEY=$3 AWS_SESSION_TOKEN=$4 && aws s3api put-object --bucket eks-for-data-silver-283429977024 --key test.txt >/dev/null && echo "put ok" && aws s3api delete-object --bucket eks-for-data-silver-283429977024 --key test.txt && echo "delete ok"'
   ```

   - Expected result: `put ok`, then `delete ok`.

   Delete the test namespace:

   ```bash
   kubectl delete namespace polaris
   ```

   - Expected result: `namespace "polaris" deleted`.

6. In the AWS console (region `us-east-1`):
   - **S3** → **General purpose buckets**: `eks-for-data-silver-283429977024`.
   - **IAM** → **Roles**: `eks-for-data-spark`, `eks-for-data-polaris` and `eks-for-data-silver-data`.
   - `eks-for-data-silver-data` → **Trust relationships**.
   - Expected result: the bucket and the three roles exist; the trust policy names only
     `arn:aws:iam::283429977024:role/eks-for-data-polaris`.

### 03.03 — Spark Image

1. Build, log in and push the image: [Run, 1. Build and Push the Spark Image](HOW_TO_RUN.md#1-build-and-push-the-spark-image),
   steps 1 to 4.
   - Expected result: the build ends with `naming to ghcr.io/andrerosalopes/spark:4.0.5-iceberg1.12.0`;
     `docker login` prints `Login Succeeded`; `docker push` ends with a line
     `4.0.5-iceberg1.12.0: digest: sha256:...`.

2. Make the package public: [Run, 1. Build and Push the Spark Image](HOW_TO_RUN.md#1-build-and-push-the-spark-image),
   step 5.
   - Expected result: GitHub shows the `spark` package as **Public**.

3. Pull the image without credentials:

   ```bash
   docker logout ghcr.io
   ```

   ```bash
   docker pull ghcr.io/andrerosalopes/spark:4.0.5-iceberg1.12.0
   ```

   - Expected result: `Removing login credentials for ghcr.io`, then the pull ends with
     `Status: Image is up to date for ghcr.io/andrerosalopes/spark:4.0.5-iceberg1.12.0` (or
     `Downloaded newer image`), with no `unauthorized` error.

### 03.04 — Spark Operator and Bronze Read Job

1. In the Argo CD UI ([How to Run, 4.3 Argo CD](../../HOW_TO_RUN.md#43-argo-cd)), open
   **Applications**.
   - Expected result: `spark-operator` and `spark-jobs` are **Synced** and **Healthy**.

2. Make sure bronze has orders (the lab02 sync in
   [phase 02](../02-transactional-ingestion/lab02-cursor-ingestion.md)), then run the job:
   [Run, 2. Run the Bronze Read Job](HOW_TO_RUN.md#2-run-the-bronze-read-job), steps 1 to 3.
   - Expected result: the state ends as `COMPLETED`.

3. Read the counts: [Run, 2. Run the Bronze Read Job](HOW_TO_RUN.md#2-run-the-bronze-read-job),
   step 4, and compare `rows` with the DuckDB count of bronze `orders` (lab02 query in
   [lab02-cursor-ingestion.md](../02-transactional-ingestion/lab02-cursor-ingestion.md)).
   - Expected result: a line `bronze orders: rows=<n> distinct_orderkey=<m>`, with `<n>` equal to
     DuckDB's bronze count.

### 03.05 — Catalog Postgres and Polaris

1. Bootstrap the realm: [Run, 3. Bootstrap the Polaris Realm](HOW_TO_RUN.md#3-bootstrap-the-polaris-realm).
   - Expected result: `Realm 'POLARIS' successfully bootstrapped.`, `Bootstrap completed
     successfully.`, then `pod "polaris-bootstrap" deleted from polaris namespace`.

2. Create a test catalog named `verify`: [Run, 4. Create a Catalog](HOW_TO_RUN.md#4-create-a-catalog),
   steps 1 to 4, with `verify` in place of `<catalog>`.
   - Expected result: `catalogs list` shows `verify`, with `default-base-location`
     `s3://eks-for-data-silver-283429977024/verify` and `roleArn`
     `arn:aws:iam::283429977024:role/eks-for-data-silver-data`.

3. After the agent's credential-vending check, in the AWS console (region `us-east-1`):
   **S3** → `eks-for-data-silver-283429977024` → `verify/`.
   - Expected result: a test table folder with a `metadata/` file ending in `.metadata.json`; the
     agent then removes the test table and namespace.

### 03.06 — Dedup Job and DuckDB Read-Back

1. Create the engines' principal with the names you choose:
   [Run, 5. Create the Engines' Principal](HOW_TO_RUN.md#5-create-the-engines-principal).
   - Expected result: `principals list` (same CLI options as in step 1 of Run 5) shows your
     principal; `kubectl -n spark get secret polaris-credentials` and
     `kubectl -n duckdb get secret polaris-credentials` both find the Secret.

2. Run the dedup job: [Run, 6. Run the Dedup Job](HOW_TO_RUN.md#6-run-the-dedup-job).
   - Expected result: state `COMPLETED`; the driver log shows
     `silver <namespace>.<table>: rows=<n> distinct_orderkey=<n>`, both numbers equal.

3. Read the table in DuckDB: [Run, 7. Read the Table with DuckDB](HOW_TO_RUN.md#7-read-the-table-with-duckdb).
   - Expected result: `silver_rows` equals `bronze_orderkeys`.

## End-to-End Verification

Proves the phase [Done When](plan.md#done-when), in a fresh environment, in this order:

1. Bring up the environment and the Polaris realm:
   [How to Run, 3. Bring Up](../../HOW_TO_RUN.md#3-bring-up), items 1 to 5.
   - Expected result: Argo CD shows every Application **Synced** and **Healthy**; the bootstrap
     prints `Realm 'POLARIS' successfully bootstrapped.`

2. Load the source and fill bronze:
   [Lab 00 — TPC-H Generation](../02-transactional-ingestion/lab00-tpch-generation.md), then
   [Lab 02 — Date Cursor Ingestion](../02-transactional-ingestion/lab02-cursor-ingestion.md),
   sections 1 to 4.
   - Expected result: bronze `orders` equals Postgres `oltp.orders` (lab02, section 4).

3. **A Spark job on the cluster reads the bronze Parquet files:**
   [Run, 2. Run the Bronze Read Job](HOW_TO_RUN.md#2-run-the-bronze-read-job).
   - Expected result: `COMPLETED`; `bronze orders: rows=<n>` with `<n>` equal to bronze in step 2.

4. **The table exists in the REST catalog, one row per `orderkey`:**
   [Run, 4. Create a Catalog](HOW_TO_RUN.md#4-create-a-catalog),
   [5. Create the Engines' Principal](HOW_TO_RUN.md#5-create-the-engines-principal) and
   [6. Run the Dedup Job](HOW_TO_RUN.md#6-run-the-dedup-job).
   - Expected result: `COMPLETED`; `rows` equals `distinct_orderkey` in the driver log.

5. **DuckDB reads the table through the catalog; its count equals the distinct `orderkey` in
   bronze:** [Run, 7. Read the Table with DuckDB](HOW_TO_RUN.md#7-read-the-table-with-duckdb).
   - Expected result: `silver_rows` = `bronze_orderkeys`.

6. **No secrets in the repository:** search the repository for the value of every `.env` variable
   whose name has `PASSWORD`, `SECRET` or `TOKEN` (the others, such as the account ID, are not
   secrets, [D-020](../../docs/decisions/020-aws-account-id-in-git.md)):

   ```bash
   while IFS='=' read -r k v; do [ -n "$v" ] && git grep -q -F "$v" && echo "FOUND: $k"; done < <(grep -E '^[A-Z_]*(PASSWORD|SECRET|TOKEN)[A-Z_]*=' .env); echo "search done"
   ```

   - Expected result: only `search done`, with no `FOUND:` line.

7. **The teardown removes every resource that incurs cost:**
   [How to Run, 5.1 Turn Off](../../HOW_TO_RUN.md#51-turn-off), then
   [5.2 Check Nothing Is Left](../../HOW_TO_RUN.md#52-check-nothing-is-left).
   - Expected result: no EKS cluster, EC2 instance, EBS volume, NAT Gateway, load balancer or
     bucket of the project remains.

## Teardown

The whole environment: [How to Run, 5. Teardown](../../HOW_TO_RUN.md#5-teardown). Each step's own
teardown is in its spec:

- [03.02 — Silver Bucket and IRSA Roles](02-silver-bucket-and-irsa/spec.md#teardown)
- [03.03 — Spark Image](03-spark-image/spec.md#teardown)
- [03.04 — Spark Operator and Bronze Read Job](04-spark-operator/spec.md#teardown)
- [03.05 — Catalog Postgres and Polaris](05-catalog-postgres-and-polaris/spec.md#teardown)
- [03.06 — Dedup Job and DuckDB Read-Back](06-dedup-job-and-duckdb/spec.md#teardown)
