[How to Run](../../HOW_TO_RUN.md) › 03 — Processing: Spark and Iceberg: **Run** | [Verify](README.md)

# 03 — Processing: Spark and Iceberg: How to Run

What to execute in this phase, once the environment is up. The checks and expected results are in
[Verify](README.md).

## Prerequisites

- The environment up: [How to Run, 3. Bring Up](../../HOW_TO_RUN.md#3-bring-up). The silver bucket
  and the Spark and Polaris roles come with `infra/aws/cluster` (step 03.02).

## 1. Build and Push the Spark Image

Builds the Spark image from [`platform/images/spark/Dockerfile`](../../platform/images/spark/Dockerfile)
(the official Spark 4.0.5 image plus the S3A, Iceberg and AWS SDK jars, each checked by SHA-256) and
pushes it to `ghcr.io` ([D-055](../../docs/decisions/055-spark-image-build.md)). Needed only when the
Dockerfile changes; safe to run again. It needs Docker Desktop running (x86) and, for the push, the
GitHub CLI (`gh`) logged in with the `write:packages` scope; no token is stored in `.env`.

1. Add the `write:packages` scope to the `gh` login (once; it opens the browser to approve):

   ```bash
   gh auth refresh -h github.com -s write:packages
   ```

2. Build the image (about 2 minutes; it downloads about 760 MB of jars):

   ```bash
   docker build -t ghcr.io/andrerosalopes/spark:4.0.5-iceberg1.12.0 platform/images/spark
   ```

3. Log in to `ghcr.io` with the `gh` token:

   ```bash
   gh auth token | docker login ghcr.io -u andrerosalopes --password-stdin
   ```

4. Push the image (uploads about 1.5 GB the first time):

   ```bash
   docker push ghcr.io/andrerosalopes/spark:4.0.5-iceberg1.12.0
   ```

5. Only after the first push: make the package public on GitHub (**Your profile** → **Packages** →
   `spark` → **Package settings** → **Change visibility** → **Public**), so the cluster pulls it
   without credentials ([D-047](../../docs/decisions/047-spark-dependencies.md)).

## 2. Run the Bronze Read Job

Reads the bronze `orders` written by lab02 and prints the row count and the distinct `orderkey`
count ([`read_bronze_orders.py`](../../pipelines/spark/read_bronze_orders.py)). It needs data in
`oltp_cursor/oltp/orders/`: run the lab02 sync first if bronze is empty. Takes about 2 minutes.
A finished job stays in the cluster, so delete it before running it again (D-057).

1. Delete the previous run, if any:

   ```bash
   kubectl -n spark delete sparkapplication read-bronze-orders --ignore-not-found
   ```

2. Start the job:

   ```bash
   kubectl apply -f pipelines/spark/read-bronze-orders.yaml
   ```

3. Follow its state until `COMPLETED` (Ctrl+C to stop watching):

   ```bash
   kubectl -n spark get sparkapplication read-bronze-orders -w
   ```

4. Read the counts in the driver log:

   ```bash
   kubectl -n spark logs read-bronze-orders-driver | grep "bronze orders"
   ```

## 3. Bootstrap the Polaris Realm

Creates Polaris's tables in the catalog Postgres and the root credentials of realm `POLARIS`, with
the Polaris admin tool ([D-059](../../docs/decisions/059-polaris-realm-bootstrap.md)). Run it once
per environment, after Argo CD shows `polaris-postgres` and `polaris` **Synced** and **Healthy**.
It is safe to run again: a bootstrapped realm is left unchanged. It reads `POLARIS_PG_PASSWORD` and
`POLARIS_ROOT_SECRET` from `.env` ([How to Run, 3.2](../../HOW_TO_RUN.md#32-services-with-argo-cd)).

```bash
set -a; source .env; set +a
```

```bash
kubectl -n polaris run polaris-bootstrap --rm -i --restart=Never --image=apache/polaris-admin-tool:1.8.0 --env="polaris.persistence.type=relational-jdbc" --env="quarkus.datasource.username=polaris" --env="quarkus.datasource.password=$POLARIS_PG_PASSWORD" --env="quarkus.datasource.jdbc.url=jdbc:postgresql://polaris-postgres.polaris.svc.cluster.local:5432/polaris" -- bootstrap -r POLARIS -c "POLARIS,root,$POLARIS_ROOT_SECRET"
```

## 4. Create a Catalog

Creates, with the Polaris CLI ([D-060](../../docs/decisions/060-polaris-catalog-creation.md)), a
catalog whose tables live in the silver bucket and whose credentials Polaris vends by assuming the
silver data role ([D-049](../../docs/decisions/049-silver-storage-credentials.md)). You choose the
catalog name in the lab; the commands below use `<catalog>`. Needs the realm bootstrapped
([3](#3-bootstrap-the-polaris-realm)) and Python 3.10 to 3.14.

1. Install the CLI (once):

   ```bash
   pip install apache-polaris==1.8.0
   ```

2. In another terminal, forward the Polaris port ([How to Run, 4.7 Polaris](../../HOW_TO_RUN.md#47-polaris)):

   ```bash
   kubectl -n polaris port-forward svc/polaris 8181:8181
   ```

3. Create the catalog, with its base location inside the silver bucket:

   ```bash
   polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" catalogs create --storage-type s3 --default-base-location s3://eks-for-data-silver-283429977024/<catalog> --role-arn arn:aws:iam::283429977024:role/eks-for-data-silver-data --region us-east-1 <catalog>
   ```

4. List the catalogs:

   ```bash
   polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" catalogs list
   ```
