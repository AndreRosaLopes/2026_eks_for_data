# Project Architecture Image Layout

Where each project component goes in the architecture image for LinkedIn, following the patterns
in [layout-patterns.md](layout-patterns.md). The image shows the whole project, including the
components still in development. Colors are not covered.

Decisions:

1. **Spark builds both Silver and Gold**; no other transform tool is shown.
2. **Gold, Metabase, Prometheus and Grafana** are drawn the same as the built components, with no
   "planned" marking.
3. **dbt, Trino, Azure and GCP** are left out.
4. **The author's LinkedIn photo** is the signature in the bottom-right.

## 1. Mapping by zone

| Zone in the patterns | Project component | What it does in the project | How to draw it |
|---|---|---|---|
| **Header, title (top-left)** | Project name | "Open Data Platform" | Title and subtitle |
| **Header, product logo (top-right)** | AWS + Kubernetes | The cloud and the runtime | Largest logo pair |
| **Far left: environment / infrastructure** | **Terraform** | Creates the network, the cluster, the buckets, Argo CD and Velero (`infra/aws/`) | Top band |
| | **Amazon VPC** | Private network with NAT gateways and a free S3 endpoint | Middle band, AWS group |
| | **Amazon EKS (Auto Mode)** | The managed Kubernetes cluster | Middle band, AWS group |
| | **IAM (IRSA)** | One AWS role per service, linked to its Kubernetes service account. IRSA = IAM Roles for Service Accounts | Middle band, small icon |
| | **Velero** | Backs up the databases and buckets when the lab is turned off and restores them when it comes back up | Bottom band, "Lab state" |
| **Wrapping the center: CI/CD / governance** | **GitHub + Argo CD** | GitOps: every service is a manifest in Git, and Argo CD applies it to the cluster | A dashed box around the whole Kubernetes area, with both logos on the frame line |
| **Left-center: data source** | **PostgreSQL** | Simulated transactional (OLTP) database holding TPC-H data, with CDC (Change Data Capture) | Main logo in the column |
| | **DuckDB** | Generates the TPC-H data and is used to explore it | Second logo, labelled "Data generation" |
| **Center-left: extract and load** | **Airbyte** | Copies the Postgres tables to S3 with an incremental cursor and with CDC | Single logo |
| **Center: storage + transformation** | **S3 Bronze (Parquet)** | Raw layer written by Airbyte | Bronze bucket |
| | **Apache Spark (Spark Operator)** | Bronze → Silver (deduplication) and Silver → Gold | Transform logo between the buckets |
| | **S3 Silver + Apache Iceberg** | Clean Iceberg tables | Silver bucket carrying the Iceberg logo |
| | **S3 Gold + Apache Iceberg** | Business-ready Iceberg tables | Gold bucket carrying the Iceberg logo |
| | **Apache Polaris** | Iceberg REST catalog for Silver and Gold: it stores which tables exist and where their files are | Above the Silver and Gold buckets, labelled "Catalog" |
| **Across the center: orchestration** | **Apache Airflow** | Triggers Airbyte and Spark | Dashed box around Airbyte → Bronze → Silver → Gold, with the Airflow logo at the bottom center |
| **Side band: observability** | **Prometheus + Grafana** | Metrics and dashboards for the platform | A vertical band along the edge of the Kubernetes area |
| **Far right: BI** | **Metabase** | Dashboards over the Gold tables | Last column, outside the orchestration box |
| **Footer, signature (bottom-right)** | **Author photo + name and title** | Identifies the author | Small round photo, ~7–9% W, with the name and title beside it |

## 2. Left out

Internal support pieces that are not drawn:

- The Postgres databases for Airflow and for Polaris.
- The buckets for Airbyte, Airflow logs and Velero.
- The storage class and the snapshot controller.
- The `up.sh` and `down.sh` scripts.

## 3. Sketch

```text
┌ Title: OPEN DATA PLATFORM ON KUBERNETES ──────────────────────────────── [AWS + K8s] ┐
│┌──────────┐ ┌ ─ ─ ─ ─ ─ GITOPS: GitHub + Argo CD ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐ │
││TERRAFORM │ │O│ SOURCE     ┌ ─ ─ ─ ─ ORCHESTRATION ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐  BI      │ │
││──────────│ │B│ PostgreSQL │ AIRBYTE → [BRONZE] → SPARK → [SILVER] →  │           │ │
││AWS: VPC  │ │S│ DuckDB   → │                      SPARK → [GOLD]      │→ METABASE │ │
││EKS · IRSA│ │ │            │          Iceberg + Polaris (catalog)     │           │ │
││──────────│ │P│Grafana     └ ─ ─ ─ ─ ─ ─ ─ AIRFLOW ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘           │ │
││VELERO    │ │ │Prometheus                                                        │ │
│└──────────┘ └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘ │
└──────────────────────────────────────────────────────── (photo) Name · Title ┘
```

About 18 logos, above the readable range of 10–15 ([layout-patterns.md](layout-patterns.md),
section 7). Writing VPC and IRSA as text in the AWS band instead of as icons brings it to 16.

## 4. Author photo

Image-generation models cannot reproduce a face faithfully. Leave an empty circle in the prompt
and paste the real photo in afterwards (for example, in Canva).
