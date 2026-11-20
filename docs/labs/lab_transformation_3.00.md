[Labs](README.md) › 3.00

# Lab 3.00 — Polaris Catalog Setup

## Goal

Create, in Polaris, the catalog that holds the silver and gold Iceberg tables, and give Spark and
DuckDB access to it. At the end, the DuckDB UI has the catalog attached as `lake`, and labs 3.01 and
3.02 can write and read their tables.

## Prerequisites

1. The environment up, from the repository root in Git Bash:

   ```bash
   ./scripts/up.sh
   ```

   It also bootstraps the Polaris realm and creates the root credentials (see
   [Concepts](#concepts)).

2. Polaris, its Postgres, Spark and DuckDB running:

   ```bash
   kubectl -n argocd get applications polaris-postgres polaris spark-operator duckdb
   ```

   Expected: the four `Synced` and `Healthy`.

3. Python 3.10 to 3.14 and the Polaris command-line program (CLI):

   ```bash
   pip install apache-polaris==1.8.0
   ```

   ```bash
   polaris --version
   ```

   Expected: `polaris 1.8.0`.

4. The `.env` variables loaded in the Git Bash window you will use for the steps:

   ```bash
   set -a; source .env; set +a
   ```

5. The Polaris tunnel. In a second Git Bash window, leave it running:

   ```bash
   kubectl -n polaris port-forward svc/polaris 8181:8181
   ```

   The CLI reaches `localhost:8181` by default.

6. The DuckDB UI open. In a third Git Bash window, leave this loop running:

   ```bash
   while true; do kubectl -n duckdb port-forward deploy/duckdb 4213:4213; sleep 1; done
   ```

   Open `http://localhost:4213`. The local port must be 4213. The tunnel often drops
   (`lost connection to pod`): the loop reconnects it, then reload the page.

## Concepts

- **Iceberg:** an open table format. An Iceberg table is a set of Parquet data files plus metadata
  files that list them, so engines get transactions (a write is all or nothing), snapshots (each
  write is a version you can read back) and schema changes. Silver and gold are Iceberg tables;
  bronze stays as the plain Parquet files Airbyte writes, read directly from S3.
- **Catalog:** the service that keeps the list of tables and, for each one, its current metadata
  file. Without it, two engines could not agree on which version of a table is current. The
  catalog does no processing: Spark writes, DuckDB reads.
- **Iceberg REST catalog:** an HTTP API that every engine speaks. It is a specification, not a
  server: one implementation must be chosen.
- **Why Polaris:** Apache Polaris implements that API. It is an Apache Software Foundation project,
  not tied to one vendor, works with Spark, Trino, Flink, DuckDB and others, and runs on Kubernetes,
  so the same catalog runs on any cloud ([D-044](../decisions/044-iceberg-rest-catalog-server.md)).
  It has no UI: you use its CLI.
- **Realm and root credentials:** a realm is Polaris's tenant, here `POLARIS`. `up.sh` bootstraps
  it once and creates the root credentials: client ID `root` and secret `POLARIS_ROOT_SECRET` in
  `.env` ([D-059](../decisions/059-polaris-realm-bootstrap.md)). Root has every right; use it only
  to administer Polaris, never in an engine.
- **Catalog in Polaris:** the named container for Iceberg tables, with a storage configuration: a
  base location (where its tables' files go) inside the silver bucket, and the IAM role Polaris uses
  to write there. You choose its name ([D-060](../decisions/060-polaris-catalog-creation.md)).
- **One catalog for silver and gold:** the role Polaris uses can only read and write the silver
  bucket, so every catalog lives there, and there is no gold bucket. Silver and gold tables go into
  the same catalog, each lab in its own **namespace** (a folder of tables inside the catalog), which
  the lab's job creates.
- **Credential vending:** Spark and DuckDB hold no permission on the silver bucket. For each table,
  Polaris assumes the role `eks-for-data-silver-data` and hands the engine short-lived credentials
  for that table only ([D-049](../decisions/049-silver-storage-credentials.md)).
- **Principal and roles:** a principal is an identity with its own client ID and secret, here
  `engines`, shared by Spark and DuckDB ([D-062](../decisions/062-polaris-engine-credentials.md)).
  Rights are given in a chain: principal → principal role (`engine_role`) → catalog role
  (`prod_contributor`, for a catalog named `prod`) → privilege on the catalog. `CATALOG_MANAGE_CONTENT` lets it create,
  read, write and drop namespaces and tables in that catalog. The names `engines`, `engine_role` and
  `prod_contributor` are examples you may change.
- **Who chooses the credentials:** creating a principal always generates a random client ID and
  secret. Root can then reset them to values it chooses (`principals reset`, on by default through
  the setting `ENABLE_CREDENTIAL_RESET`). The lab uses this to keep the engine credentials in
  `.env`: the same values in every environment, even when Polaris starts empty.
- **OAuth2 client credentials:** each engine sends its client ID and secret to Polaris, gets a
  token, and calls the catalog with it.
- **Where the setup lives:** the catalog, the principal and the roles live in the catalog Postgres
  (`polaris-postgres`), which the turn-off backs up and the next bring-up restores. The engine
  credentials live in `.env` and reach the pods as Secret `polaris-credentials`; Secrets are
  recreated on every bring-up, so that step is repeated each time.

## Steps

### 1. First Time or Continue

Check whether a catalog already exists:

```bash
polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" catalogs list
```

- **Continue** (a catalog is listed): the catalog, principal and roles came back with the restore.
  Go to [step 5](#5-give-the-credentials-to-spark-and-duckdb).
- **First time** (nothing listed): continue below.

Make sure `.env` has the engine credentials. Each command adds its line only if it is missing, with
a random value (16 hexadecimal characters for the client ID, 32 for the secret); existing values
are kept:

```bash
grep -q "^POLARIS_CLIENT_ID=." .env || echo "POLARIS_CLIENT_ID=$(openssl rand -hex 8)" >> .env
```

```bash
grep -q "^POLARIS_CLIENT_SECRET=." .env || echo "POLARIS_CLIENT_SECRET=$(openssl rand -hex 16)" >> .env
```

```bash
set -a; source .env; set +a
```

Choose the catalog name and keep it in a variable for the next commands (lowercase letters, digits
and `_`); labs 3.01 and 3.02 use the same name. This lab uses `prod` as the example:

```bash
CATALOG=prod
```

> **Replace `prod` with the catalog name you want**, here and wherever `prod` appears below (the
> catalog role `prod_contributor` and the `ATTACH` in step 6). The commands that use `$CATALOG`
> follow the variable. Set it again in every new Git Bash window.

### 2. Create the Catalog

Its base location is a folder of the silver bucket named after the catalog:

```bash
polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" catalogs create --storage-type s3 --default-base-location "s3://eks-for-data-silver-283429977024/$CATALOG" --role-arn arn:aws:iam::283429977024:role/eks-for-data-silver-data --region us-east-1 "$CATALOG"
```

```bash
polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" catalogs list
```

Expected: the catalog listed, with its base location and role.

### 3. Create the Principal

Create `engines`, discarding the random credentials Polaris generates:

```bash
polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" principals create engines > /dev/null
```

Replace them with the ones in `.env`. The output shows the principal with its new credentials; it
is printed only in your terminal, and `.env` is not versioned, so the secret stays out of the
repository:

```bash
polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" principals reset engines --new-client-id "$POLARIS_CLIENT_ID" --new-client-secret "$POLARIS_CLIENT_SECRET"
```

Expected: `clientId` equal to `POLARIS_CLIENT_ID` in `.env`.

### 4. Create the Roles and Grant the Privilege

Principal role, given to the principal:

```bash
polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" principal-roles create engine_role
```

```bash
polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" principal-roles grant --principal engines engine_role
```

Catalog role, given to the principal role:

```bash
polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" catalog-roles create --catalog "$CATALOG" "${CATALOG}_contributor"
```

```bash
polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" catalog-roles grant --catalog "$CATALOG" --principal-role engine_role "${CATALOG}_contributor"
```

Privilege on the catalog, given to the catalog role:

```bash
polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" privileges catalog grant --catalog "$CATALOG" --catalog-role "${CATALOG}_contributor" CATALOG_MANAGE_CONTENT
```

### 5. Give the Credentials to Spark and DuckDB

Create Secret `polaris-credentials` in the `spark` and `duckdb` namespaces, then restart DuckDB so
it reads it. If a Secret already exists, its command fails with `AlreadyExists`: that Secret is
already in place. If `.env` changed since it was created, delete it first
(`kubectl -n <namespace> delete secret polaris-credentials`) and create it again.

```bash
kubectl -n spark create secret generic polaris-credentials --from-literal=POLARIS_CLIENT_ID="$POLARIS_CLIENT_ID" --from-literal=POLARIS_CLIENT_SECRET="$POLARIS_CLIENT_SECRET"
```

```bash
kubectl -n duckdb create secret generic polaris-credentials --from-literal=POLARIS_CLIENT_ID="$POLARIS_CLIENT_ID" --from-literal=POLARIS_CLIENT_SECRET="$POLARIS_CLIENT_SECRET"
```

```bash
kubectl -n duckdb rollout restart deploy/duckdb
```

The restart drops the DuckDB UI tunnel; the loop reconnects it. Reload the page.

### 6. Attach the Catalog in the DuckDB UI

In the DuckDB UI, log in to Polaris as `engines`, with the credentials read from the pod's
environment, then attach the catalog as `lake`. Run each statement **in its own cell, in this
order**: the UI checks every statement of a cell before running any, so an `ATTACH` in the same
cell as `CREATE SECRET` fails with "No ICEBERG secret by the name of 'polaris' could be found"
([D-043](../decisions/043-pipeline-script-execution.md)). DuckDB keeps both only until the pod
restarts: run both cells again after each restart.

First cell, the login:

```sql
CREATE SECRET polaris (TYPE iceberg, CLIENT_ID getenv('POLARIS_CLIENT_ID'), CLIENT_SECRET getenv('POLARIS_CLIENT_SECRET'), OAUTH2_SERVER_URI 'http://polaris.polaris.svc.cluster.local:8181/api/catalog/v1/oauth/tokens', OAUTH2_SCOPE 'PRINCIPAL_ROLE:ALL');
```

Second cell, the catalog. **Replace `prod` with your catalog name:**

```sql
ATTACH 'prod' AS lake (TYPE iceberg, URI 'http://polaris.polaris.svc.cluster.local:8181/api/catalog', SECRET polaris, ACCESS_DELEGATION_MODE 'vended_credentials');
```

Expected: both cells succeed. If the first one says the secret already exists, it was created
earlier in this session: run only the second.

## Validation

1. The chain of rights, from the Git Bash window with `CATALOG` set:

   ```bash
   polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" principal-roles list --principal engines
   ```

   Expected: `engine_role`.

   ```bash
   polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" catalog-roles list --principal-role engine_role "$CATALOG"
   ```

   Expected: `prod_contributor` (your catalog name followed by `_contributor`).

   ```bash
   polaris --client-id root --client-secret "$POLARIS_ROOT_SECRET" privileges list --catalog "$CATALOG" --catalog-role "${CATALOG}_contributor"
   ```

   Expected: `CATALOG_MANAGE_CONTENT`.

2. The engine credentials work: log in as `engines` instead of root and list the namespaces:

   ```bash
   polaris --client-id "$POLARIS_CLIENT_ID" --client-secret "$POLARIS_CLIENT_SECRET" namespaces list --catalog "$CATALOG"
   ```

   Expected: no error; an empty list on a new catalog, or the namespaces of earlier labs.

3. The Secrets exist in both namespaces:

   ```bash
   kubectl get secret polaris-credentials -n spark -o name; kubectl get secret polaris-credentials -n duckdb -o name
   ```

   Expected: `secret/polaris-credentials` twice.

4. In the DuckDB UI, `lake` is attached:

   ```sql
   SELECT database_name, type FROM duckdb_databases() WHERE database_name = 'lake';
   ```

   Expected: `lake`, `iceberg`.

## Questions

1. Why do silver and gold need a catalog, while bronze does not?
2. Why do Spark and DuckDB log in as `engines` instead of `root`?
3. Spark has no permission on the silver bucket. How does it write there?
4. After a turn-off and a new bring-up, which steps of this lab do you repeat, and why?

## Cleanup

Stop the tunnels with `Ctrl+C` in their windows. Keep the catalog, the principal and the roles: labs
3.01 and 3.02 use them, and they live in the catalog Postgres, which the turn-off backs up and the
next bring-up restores. Keep `POLARIS_CLIENT_ID` and `POLARIS_CLIENT_SECRET` in `.env`.
