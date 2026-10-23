# Platform Architecture

How the deployed platform is built and how its parts connect. Each implemented step adds its section.
Exact values and decisions live in the step specs and ADRs linked in each section.

## 1. AWS

### 1.1 Network (step 01.01)

Source: [01.01 — Network specification](../specs/01-ingestion-airbyte-s3/01-network/spec.md).

#### Overview

```text
                                Internet
                                   │
VPC eks-for-data-vpc     ┌─────────┴─────────┐
(10.0.0.0/16) us-east-1  │ Internet Gateway  │  (attached to the VPC)
┌────────────────────────┴───┬───────────┬───┴────────────────────────┐
│  us-east-1a (use1-az1)     │           │     us-east-1b (use1-az2)  │
│               ┌────────────┘           └────────────┐               │
│  ┌────────────┴─────────────┐         ┌─────────────┴────────────┐  │
│  │ Public 10.0.64.0/24      │         │ Public 10.0.65.0/24      │  │
│  │   NAT Gateway ── EIP     │         │   NAT Gateway ── EIP     │  │
│  └────────────▲─────────────┘         └─────────────▲────────────┘  │
│               │                                     │               │
│  ┌────────────┴─────────────┐         ┌─────────────┴────────────┐  │
│  │ Private 10.0.0.0/19      │         │ Private 10.0.32.0/19     │  │
│  │ (EKS nodes and pods)     │         │ (EKS nodes and pods)     │  │
│  └────────────┬─────────────┘         └─────────────┬────────────┘  │
│               └──────────────┐   ┌──────────────────┘               │
│                       ┌──────┴───┴─────┐                            │
│                       │  S3 endpoint   │  (Gateway, free)           │
│                       └───────┬────────┘                            │
└───────────────────────────────┼─────────────────────────────────────┘
                                ▼
                            Amazon S3
```

#### Components

| Component | What it does |
|---|---|
| **VPC** `10.0.0.0/16` | The project's private, isolated network, with about 65,000 IPs |
| **2 AZs** | Two independent data centers in the region: if one fails, the other keeps running. `use1-az3` is excluded because EKS does not accept subnets there |
| **Public subnets** (`/24`) | Have a direct route to the internet through the Internet Gateway. They only host the NAT Gateways |
| **Private subnets** (`/19`, about 8,000 IPs each) | No public IPs, unreachable from the internet. They host the EKS nodes. They are large because on EKS each pod gets a VPC IP |
| **Internet Gateway** | The VPC's door to the internet, used by the public subnets |
| **NAT Gateway** (one per AZ) | Lets the private subnets *go out* to the internet (pull images, call the public API) without anyone outside being able to *come in* |
| **Elastic IP (EIP)** (one per NAT) | Fixed public IPv4 address reserved in the account and attached to each NAT Gateway: all outbound traffic from the private subnets appears on the internet with one of these 2 IPs (the ones to allowlist in an external API). It does not change while the EIP exists |
| **S3 endpoint (Gateway)** | Private shortcut from the VPC to S3: traffic to the buckets bypasses the NAT (saving US$ 0.045/GB) and never leaves for the internet |

#### Traffic Flow

| Source → destination | Path |
|---|---|
| Pod in `1a` → internet (e.g., public API) | Private subnet 1a → NAT in 1a → Internet Gateway → internet |
| Pod in `1b` → internet | Private subnet 1b → NAT in **1b**. Each AZ uses its own NAT ([D-005](decisions/005-network-topology.md)): if 1a fails, 1b keeps going out |
| Pod → S3 | Private subnet → S3 endpoint → S3, with no NAT and no internet |
| Internet → pod | Blocked: there is no inbound route to the private subnets |

The **route tables** implement this: each private subnet has its own (`0.0.0.0/0` → NAT of its AZ;
S3 prefix list → endpoint); the public subnets share one (`0.0.0.0/0` → Internet Gateway).
Outbound access through the NATs is first exercised in step 01.02, when the nodes pull images.

#### Code

| File | Content |
|---|---|
| `infra/aws/cluster/providers.tf` | AWS provider fixed to `us-east-1`; `project` and `managed-by` tags on every resource |
| `infra/aws/cluster/network.tf` | AZ selection, `vpc` module (subnets, NATs, routes) and `vpc-endpoints` module (S3) |
| `infra/aws/cluster/outputs.tf` | VPC and subnet IDs, used by the EKS cluster |

The state is local (`infra/aws/cluster/terraform.tfstate`), outside Git
([D-002](decisions/002-terraform-state-backend.md)).

#### Cost

About **US$ 0.10/h** while it exists: 2 NATs + 2 public IPv4 addresses, plus US$ 0.045 per GB
processed by the NATs. The VPC, subnets, route tables, Internet Gateway and S3 endpoint are free.

### 1.2 Cluster Capacity (steps 01.04 and 01.05)

Sources: [01.04 — Argo CD](../specs/01-ingestion-airbyte-s3/04-argo-cd/spec.md) and
[01.05 — Airbyte](../specs/01-ingestion-airbyte-s3/05-airbyte/spec.md) (check 9: measured usage);
requests in [`platform/aws/airbyte.yaml`](../platform/aws/airbyte.yaml)
([D-018](decisions/018-workload-resource-requests.md)).

#### How Nodes Are Sized

EKS Auto Mode (`general-purpose` pool, [D-006](decisions/006-eks-compute-mode.md)) creates nodes from
the pods' **requests**, not their usage: it picks the cheapest on-demand `c`/`m`/`r` instance
(generation > 4, `amd64`) that fits the pending pods, then consolidates. Pods without requests are
invisible to it.

#### Composition

Idle usage, measured on 2026-10-23.

| Workload | Pods | Requests (CPU / memory) | Usage (CPU / memory) |
|---|---|---|---|
| Argo CD | application-controller, applicationset-controller, notifications-controller, redis, repo-server, server | None (chart defaults) | 5m / 164Mi |
| Airbyte `server` | 1 | 500m / 1Gi | 3m / 632Mi |
| Airbyte `worker` | 1 | 500m / 1Gi | 5m / 401Mi |
| Airbyte `workloadApiServer` | 1 | 250m / 768Mi | 10m / 417Mi |
| Airbyte `workloadLauncher` | 1 | 250m / 768Mi | 3m / 344Mi |
| Airbyte `cron` | 1 | 100m / 512Mi | 1m / 458Mi |
| Airbyte `manifestServer` | 1 | 250m / 512Mi | 2m / 119Mi |
| Airbyte `temporal` | 1 | 250m / 256Mi | 14m / 96Mi |
| Airbyte `airbyte-db` (Postgres) | 1 | None (chart default) | 8m / 66Mi |
| **Total** | 14 | **2100m / 4.8Gi** | **51m / 2.6Gi** |

Not included: Airbyte sync job pods (01.06), created per sync, and the system pods Auto Mode manages.

#### Resulting Nodes

2 × `c6a.large` (2 vCPU / 4 GiB each; about 1.8 vCPU / 3.0 GiB allocatable each), chosen by Auto
Mode. With requests only on Airbyte, one node did not fit them; without requests, all pods shared one
node and the five Airbyte JVMs never finished starting (CPU starvation).

#### Cost

About **US$ 0.153/h** of EC2 for the 2 nodes (on-demand, us-east-1), plus the Auto Mode fee per
instance. CPU is mostly idle and memory is about half the requests, so the requests can be lowered
once sync usage (01.06) is measured.
