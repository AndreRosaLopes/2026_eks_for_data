# Project Architecture Image Layout

Where each project component goes in the architecture image for LinkedIn, following the patterns
in [layout-patterns.md](layout-patterns.md). The image shows the whole project, including the
components still in development.

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
| **Layer 1 (outermost, leftmost): infrastructure as code** | **Terraform** | Creates the network, the cluster, the buckets, Argo CD and Velero (`infra/aws/`) | The largest card, behind everything; its left strip holds the title "Infrastructure as code" and the Terraform logo |
| | **Amazon VPC** | Private network with NAT gateways and a free S3 endpoint | Layer 2, on top of the Terraform card: its left strip holds the title "AWS" and the VPC logo |
| | **Amazon EKS (Auto Mode)** | The managed Kubernetes cluster | Layer 2 strip, EKS logo |
| | **IAM (IRSA)** | One AWS role per service, linked to its Kubernetes service account. IRSA = IAM Roles for Service Accounts | Layer 2 strip, small text "IAM · IRSA" |
| | **Velero** | Backs up the databases and buckets when the lab is turned off and restores them when it comes back up | A grey "Backup and restore" bar across the bottom of the GitOps box, from Observability to Metabase |
| **Wrapping the center: CI/CD / governance** | **GitHub + Argo CD** | GitOps: every service is a manifest in Git, and Argo CD applies it to the cluster | A dashed box around the whole Kubernetes area, with both logos on the frame line |
| **Left-center: data source** | **PostgreSQL** | Simulated transactional (OLTP) database holding TPC-H data, with CDC (Change Data Capture) | Main logo in the column |
| | **DuckDB** | Generates the TPC-H data and is used to explore it | Second logo, labelled "Data generation" |
| **Center-left: extract and load** | **Airbyte** | Copies the Postgres tables to S3 with an incremental cursor and with CDC | Single logo |
| **Center: storage + transformation** | **S3 Bronze (Parquet)** | Raw layer written by Airbyte | Bronze bucket, with an Apache Parquet format badge below it |
| | **Apache Spark (Spark Operator)** | Bronze → Silver (deduplication) and Silver → Gold | Transform logo between the buckets |
| | **S3 Silver + Apache Iceberg** | Clean Iceberg tables | Silver bucket, with an Iceberg format badge below it |
| | **S3 Gold + Apache Iceberg** | Business-ready Iceberg tables | Gold bucket, with an Iceberg format badge below it |
| | **Apache Polaris** | Iceberg REST catalog for Silver and Gold: it stores which tables exist and where their files are | A "Catalog" frame around the three format badges, with the Polaris logo inside |
| **Across the center: orchestration** | **Apache Airflow** | Triggers Airbyte and Spark | Dashed box around Airbyte → Bronze → Silver → Gold, with the Airflow logo at the top center and a thin top-down arrow from Airflow to each task it triggers (Airbyte and both Spark steps) |
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
  Title: OPEN DATA PLATFORM ON KUBERNETES                                    [AWS + K8s]
┌─────┬─────┬ ─ ─ ─ ─ ─ ─ ─ ─ GITOPS: GitHub + Argo CD ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
│  I  │  A  │┌───────┐ SOURCE     ┌ ─ ─ ─ ORCHESTRATION ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐  BI      │
│  N  │  W  ││OBSERV.│ PostgreSQL │              AIRFLOW                    │          │
│  F  │  S  ││Prometh│ DuckDB   → │   ↓            ↓              ↓         │→ METABASE│
│  R  │     ││Grafana│            │ AIRBYTE → [BRONZE] → SPARK → [SILVER]   │          │
│  A  │ EKS ││       │            │                     → SPARK → [GOLD]    │          │
│     │ VPC ││       │            │ ┌ CATALOG: Parquet · Iceberg · Iceberg ┐│          │
│ Ter-│ IAM ││       │            │ └ ─ ─ ─ ─ ─ Apache Polaris ─ ─ ─ ─ ─ ─ ┘│          │
│ ra- │ IRSA│└───────┘            └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘          │
│ form│     │[░░░░░░░░░░░░░░ BACKUP AND RESTORE · Velero ░░░░░░░░░░░░░░░░░░░░░░░░░░░░]│
└─────┴─────┴ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
 Layer 1     Layer 2   Layer 3 (GitOps box): layers peel from left to right
                                                              (photo) Name · Title
```

About 18 logos, above the readable range of 10–15 ([layout-patterns.md](layout-patterns.md),
section 7). Writing IRSA as text instead of as an icon brings it to 17.

## 4. Author photo

Image-generation models cannot reproduce a face faithfully. Leave an empty circle in the prompt
and paste the real photo in afterwards (for example, in Canva).

## 5. Color palette

Black with fluorescent lime. Near-black surfaces instead of pure black, and lime only as an accent.
Contrast between text and background is not checked yet.

| Role | Hex | Where it goes |
|---|---|---|
| Background | `#0D0F0E` | The whole page |
| Panel | `#161A18` | The main diagram panel |
| Card / band | `#1F2421` | Infrastructure bands, column cards |
| Lime accent | `#39FF14` | Title highlight, the Orchestration dashed box, flow arrows |
| Soft lime | `#89F336` | The GitOps dashed box, column headers |
| Main text | `#E8F0EA` | Tool labels |
| Muted text | `#8A968E` | Captions, subtitle |
| Bronze / Silver / Gold | `#CD7F32` / `#C0C0C0` / `#FFD700` | Only the three medallion buckets |

Tool logos keep their official colors.

View and adjust the palette:

- [Coolors](https://coolors.co/0d0f0e-161a18-1f2421-39ff14-89f336-e8f0ea-8a968e): the seven
  colors side by side.
- [Realtime Colors](https://www.realtimecolors.com/?colors=e8f0ea-0d0f0e-39ff14-89f336-1f2421):
  the palette applied to a page, with a contrast check.
