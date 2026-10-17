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
