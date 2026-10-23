# Lab 01 — API Ingestion

Create, in the Airbyte UI, a connection that reads the PokeAPI and writes Parquet files to the S3
bronze bucket, then run a sync and check the files. The configuration is not saved
([D-021](../../docs/decisions/021-airbyte-connection-ui-lab.md)): repeat this lab in every new
environment.

## Prerequisites

- Steps 01.01 to 01.05 up ([phase README](README.md)): Argo CD shows `airbyte` **Synced** and
  **Healthy**.
- Git Bash in the repository root, with `set -a; source .env; set +a`.

## 1. Open the Airbyte UI

```bash
kubectl -n airbyte get secret airbyte-auth-secrets -o jsonpath='{.data.instance-admin-password}' | base64 -d; echo
kubectl -n airbyte port-forward svc/airbyte-airbyte-server-svc 8001:8001 &
```

Open `http://localhost:8001` and sign in with your email and the password above.

## 2. Source: PokeAPI

**Sources** → **New source** → **PokeAPI** ([D-011](../../docs/decisions/011-public-api-source.md)):

| Field | Value |
|---|---|
| Source name | `PokeAPI` |
| Pokemon Name | `ditto` |

**Set up source**. Expected: the connection test passes.

## 3. Destination: S3 Bronze, Parquet

**Destinations** → **New destination** → **S3**:

| Field | Value |
|---|---|
| Destination name | `S3 bronze` |
| S3 Bucket Name | `eks-for-data-bronze-283429977024` |
| S3 Bucket Path | `pokeapi` |
| S3 Bucket Region | `us-east-1` |
| Output Format | **Parquet: Columnar Storage**, Compression Codec `SNAPPY` |
| Access Key ID, Secret Access Key, Role ARN | **Empty**: the connector uses the pod's IAM role (IRSA, `eks-for-data-airbyte`) |

**Set up destination**. Expected: the connection test passes. If it fails with `Access Denied`, the
IAM role did not reach the connector pod; stop and report it.

## 4. Connection

**Connections** → **New connection** → source `PokeAPI` → destination `S3 bronze`:

| Field | Value |
|---|---|
| Stream | `pokemon`, selected |
| Sync mode | **Full refresh \| Append** (PokeAPI has no incremental sync) |
| Schedule | **Manual** |

**Set up connection**, then **Sync now**. Expected: the sync ends as **Succeeded**.

## 5. Check the Parquet Files

```bash
aws s3 ls s3://eks-for-data-bronze-283429977024/pokeapi/pokemon/ --recursive
```

Expected: at least one object `pokeapi/pokemon/<YYYY>_<MM>_<DD>_<epoch>_0.parquet`. In the console:
**S3** → `eks-for-data-bronze-283429977024` → `pokeapi/pokemon/` shows the same file.

Read it, in a virtual environment outside the repository:

```bash
F=$(aws s3 ls s3://eks-for-data-bronze-283429977024/pokeapi/pokemon/ --recursive | tail -1 | awk '{print $4}')
aws s3 cp "s3://eks-for-data-bronze-283429977024/$F" "$TEMP/pokemon.parquet"
python -m venv "$TEMP/lab01" && "$TEMP/lab01/Scripts/pip" install -q pyarrow
"$TEMP/lab01/Scripts/python" -c "import pyarrow.parquet as pq,sys;t=pq.read_table(sys.argv[1]);print(t.schema.names);print(t.num_rows, t.column('name').to_pylist())" "$TEMP/pokemon.parquet"
```

Expected: columns including `id`, `name` and Airbyte's `_airbyte_*` metadata; `1 ['ditto']`.

## 6. Clean Up

Stop the port-forward: `jobs`, then `kill %N`. Nothing else: the source, destination and connection
disappear with Airbyte's database, and the Parquet files with the bronze bucket, at
[Turn Off](README.md#turn-off).
