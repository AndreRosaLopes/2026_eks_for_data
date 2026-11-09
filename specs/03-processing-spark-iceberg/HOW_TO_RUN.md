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
