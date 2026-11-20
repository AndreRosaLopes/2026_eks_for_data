# Layout Patterns in the Reference Images

Layout patterns found in the four reference architecture images in this folder. All measurements
are visual estimates, given as a percentage of the image width (W) or height (H); none was measured
in pixels. Colors are not covered.

| File | Image |
|---|---|
| `image.png` | Sparkanos |
| `image copy.png` | Data for Speed |
| `image copy 2.png` | Airdbt |
| `image copy 3.png` | Pentaho + AWS |

## 1. Page grid

| Zone | Sparkanos | Data for Speed | Airdbt | Pentaho + AWS | Pattern |
|---|---|---|---|---|---|
| Format | 16:9 | 16:9 | 16:9 | ~16:9 | Always landscape 16:9 |
| Header band | ~20% H | ~20% H | ~22% H | ~16% H, closed by a horizontal rule | **Top 15–22% H** |
| Diagram area | ~70% H | ~65% H | ~67% H | ~70% H | **~65–70% H, centered** |
| Footer | ~8% H | ~8% H | ~10% H | ~10% H | **Bottom ~8–10% H** |
| Side margins | ~4% W | ~5% W | ~5% W | ~7% W | **4–7% W** |

## 2. Title and logos

| Element | Position | Size | Pattern |
|---|---|---|---|
| Title ("Solution Architecture …") | Always **top-left** | Cap height ~4–5% H; spans 20–65% W | Fixed: top-left, one or two lines |
| Product logo | Top-right (Airdbt, Pentaho + AWS), top-left (Data for Speed), top-center (Sparkanos) | **~12–15% H and 18–29% W**, the largest element on the page | Usually top-right, opposite the title |
| Mascot / theme emblem | Top-right (rabbit), top-center (helmet) | ~13–15% H | Optional; only in themed images |
| Consultancy logo | Always **bottom-right** (bottom-center in Pentaho + AWS) | **~7–9% W** | Small fixed signature |
| Author credit | Bottom-left (Data for Speed) | Small text | Optional |
| Tool logos | Inside the columns | **~6–9% H**, uniform within each image; the visualization logos are slightly smaller | Same size for every tool |
| Tool label | Directly **under** each logo | Small, uppercase, bold | Always logo above, name below |

## 3. Diagram structure (nested frames)

From the outside in:

1. **Outer dashed frame** around the whole diagram (in all four images except Pentaho + AWS, which
   uses solid card outlines).
2. **Solid rounded panel** that holds the content.
3. **Inner dashed boxes** that group by function: Orchestration (Data for Speed, Airdbt), CI/CD
   (Data for Speed), Security and proxy (Sparkanos).
4. **Column cards** for each function (Sparkanos and Pentaho + AWS give every column its own card;
   Airdbt uses spacing only).

Depth ranges from two levels (Pentaho + AWS) to five (Sparkanos). The most readable images have two
or three levels.

## 4. Functional grouping and fixed positions

The order is always **left → right, following the data flow**:

| Position | Function | What goes there | How it is drawn |
|---|---|---|---|
| **Far left** (narrow, ~7–12% W) | **Environment / infrastructure** | OS, Docker, cloud, Terraform, Git | Logos **stacked vertically**, or **layered vertical bands** with **vertical text** (Airdbt). Outside the data flow |
| Left (optional) | **Platform / security** | Proxy, HTTPS, DNS, security layer | Vertical bars or columns (Sparkanos only) |
| Left-center | **Data source** | PostgreSQL, MySQL, CSV, JSON | 1–3 logos stacked vertically |
| Center-left | **Extract and load** | Airbyte, Hop, Pentaho, Python | Usually a single logo |
| **Center** (widest, 30–60% W) | **Storage + transformation** | Data lake, Spark, dbt, Bronze → Silver → Gold | **Medallion buckets in a horizontal row**, with the transform tool between or above them. Can split into lanes (DEV/QA/PRD in Data for Speed) |
| Center-right | **Serving / query** | Data warehouse, Trino, Athena, Jupyter | Shown either as part of the center block or as its own column |
| **Far right** (~10–13% W) | **BI / data visualization** | Metabase, Superset, Power BI, Tableau, Qlik | Always the **last column**, **3–4 logos stacked vertically**, **outside the orchestration box** |
| **Across the center** | **Orchestration** | Airflow | A **dashed box wrapping ingestion → transform**, with the Airflow logo at the **bottom center** of the box (Airdbt) or on a side band (Sparkanos) |
| **Wrapping the center** | **CI/CD / governance** | Git, Jenkins, OpenMetadata | A second dashed box or a side band, with labels on the frame line |

## 5. Flow inside each box

| Pattern | Where it appears |
|---|---|
| **Column header** in uppercase at the top; **logo** centered vertically; **label** below | All four images |
| **Vertical column title** written along the left edge of each column card | Sparkanos |
| **Header logo above the card**, white **tiles (icon + name)** inside, and an **outlined caption box below** that explains the column's role | Pentaho + AWS |
| Inside a box that holds several services: a **zig-zag with L-shaped arrows** (IAM → RDS → S3 → Glue → Athena) | Pentaho + AWS |
| Medallion layers in sequence, with **small arrows** between the buckets | Sparkanos, Data for Speed |

## 6. Arrows and connectors

| Type | Where | Use |
|---|---|---|
| **Large curved arrows under the logos**, one between each pair of columns | Airdbt | The clearest flow |
| **Large chevrons** between column cards | Pentaho + AWS | Flow between functions |
| **Small triangles** between columns or buckets | Sparkanos, Data for Speed | A discreet flow |
| **Dashed lines** | Data for Speed | Promotion between environments (DEV → QA → PRD) |

## 7. Density

| Image | Tools shown | Readability |
|---|---|---|
| Airdbt | ~10 | Highest |
| Pentaho + AWS | ~13 | High |
| Data for Speed | ~20 | Medium |
| Sparkanos | ~35 | Low (crowded) |

**Pattern:** the clean images show **10–15 logos**, one per function, with the BI column as the only
stacked list.
