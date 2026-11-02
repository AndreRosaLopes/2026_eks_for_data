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

## End-to-End Verification

Written on the last step: walkthrough proving the phase "Done When".

## Teardown

The whole environment: [How to Run, 5. Teardown](../../HOW_TO_RUN.md#5-teardown). Each step's own
teardown is in its spec:

- [03.02 — Silver Bucket and IRSA Roles](02-silver-bucket-and-irsa/spec.md#teardown)
