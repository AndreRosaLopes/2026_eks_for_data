# Architecture Image Prompt

Prompt to generate the LinkedIn architecture image, built from [project-layout.md](project-layout.md)
(layout, components, palette) and [layout-patterns.md](layout-patterns.md) (reference patterns).
If those files change, update this prompt.

## 1. Workflow

Image models redraw logos from memory and distort them. To use the official logos:

1. **Generate the base image** with the prompt in section 3. It leaves an empty, labelled slot for
   every logo and an empty circle for the author photo.
2. **Download the official logos** from the sources in section 2.
3. **Place the logos and the photo** on their slots in an editor (Canva, Figma or similar), keeping
   each logo unmodified, as the brand guidelines require.

Attach to the model, together with the prompt: the four reference images in this folder
(`image.png`, `image copy.png`, `image copy 2.png`, `image copy 3.png`).

## 2. Official logo sources

| Logo | Source | Checked |
|---|---|---|
| AWS, Amazon VPC, Amazon EKS, IAM, Amazon S3 | [AWS Architecture Icons](https://aws.amazon.com/architecture/icons/) | Not verified |
| Kubernetes, Argo CD, Prometheus | [CNCF artwork](https://github.com/cncf/artwork) | Repository found; project folders not verified |
| Apache Spark, Apache Iceberg, Apache Polaris, Apache Airflow | [Apache logos](https://www.apache.org/logos/), or each project's homepage | Not verified per project |
| DuckDB | [DuckDB design](https://duckdb.org/design/) | Found |
| Terraform | HashiCorp brand page | Not found |
| Velero | velero.io / GitHub `vmware-tanzu/velero` | Not found |
| GitHub | GitHub logos page | Not found |
| PostgreSQL | postgresql.org | Not found |
| Airbyte | airbyte.com | Not found |
| Grafana | grafana.com | Not found |
| Metabase | metabase.com | Not found |

## 3. Prompt

```text
Create a 16:9 (1920x1080) technical architecture infographic for a LinkedIn post. Use the attached
four images as style and layout references: same structure (title top-left, nested dashed frames,
left-to-right data flow, BI column last, small signature bottom-right), but with the dark palette
below. Do NOT draw any logos: wherever a logo goes, draw an empty rounded-square slot with a thin
#2A322D outline and write the tool name in UPPERCASE bold below it. Every logo slot has the same
size. All text must be crisp, legible and spelled exactly as written here.

PALETTE
- Page background #0D0F0E (near-black), with a very subtle dark texture.
- Main diagram panel #161A18; cards and bands #1F2421.
- Lime accent #39FF14: title highlight, the ORCHESTRATION dashed box, flow arrows, soft glow.
- Soft lime #89F336: the GITOPS dashed box and column headers.
- Main text #E8F0EA; captions and subtitle #8A968E.
- Bronze #CD7F32, silver #C0C0C0 and gold #FFD700 only for the three bucket icons.
- Lime used sparingly, as an accent; the dark tones carry the image.

HEADER (top 18% of the height)
- Top-left: small line "Solution Architecture", and below it, large and bold,
  "OPEN DATA PLATFORM ON KUBERNETES" (the words "ON KUBERNETES" in #39FF14).
- Subtitle below, in #8A968E: "Open-source lakehouse on Amazon EKS, built hands-on".
- Top-right: two large logo slots side by side, labelled "AWS" and "KUBERNETES".

LEFT COLUMN: INFRASTRUCTURE (narrow, ~10% of the width, three stacked vertical bands in #1F2421,
with the band titles written vertically)
1. Band "INFRASTRUCTURE AS CODE": one slot, "TERRAFORM".
2. Band "AWS": slots "AMAZON EKS" and "AMAZON VPC", and below them the small text "IAM · IRSA".
3. Band "LAB STATE": one slot, "VELERO", caption "Backup and restore between sessions".

MAIN AREA (to the right of the infrastructure column)
- A soft-lime (#89F336) dashed rounded box wraps the whole main area. On its top frame line:
  slots "GITHUB" and "ARGO CD", and the label "GITOPS".
- Along the left edge inside that box: a narrow vertical band titled "OBSERVABILITY" (vertical
  text) with slots "PROMETHEUS" and "GRAFANA" stacked.
- Then, left to right, with thick lime arrows between the columns:
  1. Column "DATA SOURCE": slots "POSTGRESQL" (caption "TPC-H OLTP · CDC") and "DUCKDB"
     (caption "Data generation").
  2. A lime (#39FF14) dashed rounded box titled "ORCHESTRATION" containing:
     - Column "EXTRACT AND LOAD": slot "AIRBYTE".
     - Column "BRONZE": a bronze bucket icon labelled "S3 BRONZE · PARQUET".
     - Column "TRANSFORM": slot "APACHE SPARK".
     - Column "SILVER": a silver bucket icon labelled "S3 SILVER · ICEBERG".
     - Column "TRANSFORM": slot "APACHE SPARK".
     - Column "GOLD": a gold bucket icon labelled "S3 GOLD · ICEBERG".
     - Above the silver and gold buckets: slots "APACHE ICEBERG" and "APACHE POLARIS", with the
       caption "Catalog".
     - At the bottom center of the box: slot "APACHE AIRFLOW".
  3. Column "BI", outside the orchestration box, last on the right: slot "METABASE".

FOOTER (bottom 8% of the height)
- Bottom-right: an empty circle (~7% of the width) for the author photo, with "<NAME>" and
  "<TITLE>" beside it in #E8F0EA and #8A968E.

Clean, generous spacing; no extra icons, text or decorations beyond what is listed.
```
