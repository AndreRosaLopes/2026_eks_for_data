# Open Data Platform: Multi-Cloud Learning Project

## 1. Objective

Build, test and compare an open-source data platform on the three major clouds: **AWS**, **Azure** and **GCP**.
Every component and decision must have an equivalent on all three clouds, so they can be compared side by side.
The goal is to learn modern data platform architecture by deploying it hands-on.
The platform uses open-source components on Kubernetes, with each cloud's native object storage.

## 2. Target Architecture

| Layer | Component |
|---|---|
| Ingestion | Airbyte |
| Storage | Cloud object storage (AWS S3, Azure Blob Storage / ADLS Gen2, Google Cloud Storage) |
| Compute | Kubernetes (EKS, AKS, GKE) |
| Processing engine | Trino and/or Apache Spark |
| Transformation | dbt |
| Orchestration | Apache Airflow |
| Continuous delivery (GitOps) | Argo CD |
| Observability | Prometheus + Grafana |
| BI | Metabase + dbt Charts |

## 3. Phases

A phase is a functional objective: something that works end to end. Each phase is broken into
implementation steps (see [section 7](#7-development-process-sdd)) and documented in `specs/NN-name/plan.md`.
Phases are a guide, not a fixed plan: their order and scope may change as the project evolves.

| # | Phase | Initial idea of steps |
|---|---|---|
| 01 | **Ingestion:** Airbyte writing to AWS S3 | Network and core services; Kubernetes and Argo CD; Airbyte |
| 02 | **Processing and transformation:** Trino and dbt | To be defined |
| 03 | **Orchestration:** Airflow | To be defined |
| — | **Next phases** | To be decided |

## 4. Premises

- **Learning first:** the focus is on understanding the architecture, not on delivering production systems.
- **Open source and portable:** the same stack runs on all three clouds. Only the infrastructure layer
  (network, storage, managed Kubernetes) changes per cloud.
- **Flexible roadmap:** phases can be reordered or expanded as needed.

## 5. User Personas

| Persona | Responsibility | Main tools |
|---|---|---|
| **Business users** | Query the Gold tables and use BI dashboards | Metabase, Trino (SQL) |
| **Data Engineers** | Build the data models and pipelines | Airbyte, dbt, Spark, Trino, Airflow |
| **Platform Engineers** | Provision and operate the infrastructure and platform services | Terraform/IaC, Kubernetes, Argo CD, Prometheus, Grafana |

## 6. Change Separation

- **Single monorepo:** everything lives in one repository.
- **Separate change streams:** data pipeline changes (models, DAGs, ingestion configs) are tracked
  separately from infrastructure changes (network, clusters, platform services).
- **Goal:** each kind of change has its own history, review and deployment path, so you can see
  clearly what changed and who changed it.

## 7. Development Process (SDD)

### 7.1 Concepts

- **Phase:** a functional objective, verified end to end (e.g., Airbyte writing to S3).
- **Step:** an implementation increment of a phase, verified technically (e.g., network).
  It is identified as `phase.step` (e.g., `01.02`).
- **Decision (ADR):** a choice between alternatives, made only in planning and evaluated
  against the [project principles](docs/principles.md).

### 7.2 Flow

1. **Plan the phase:** run `/sdd-plan <phase idea>`, answer the questions and approve the plan and its decisions.
2. **For each step of the plan, in order:**
   1. **Specify:** run `/sdd-spec <phase.step>` and approve the specification.
   2. **Implement:** run `/sdd-implement <phase.step>` and confirm each irreversible or costly action.
   3. **Verify the step:** follow the step's section in the phase README and confirm that it works.
3. **Verify the phase:** on the last step, also follow the end-to-end verification in the phase README
   and confirm that it works.

### 7.3 Skills

| Skill | Input | Outputs | Your action |
|---|---|---|---|
| `/sdd-plan` | Phase idea (free text) | `specs/NN-phase/plan.md`: objective, scope, out of scope, done when, decisions, steps. `docs/decisions/NNN-name.md`: one ADR per decision | Answer questions; approve |
| `/sdd-spec` | `phase.step` of an approved plan | `specs/NN-phase/NN-step/spec.md`: design, files, verification plan, teardown | Approve |
| `/sdd-implement` | `phase.step` of an approved spec | Code; verification results in `spec.md`; status in `plan.md`. Every step: its section in `specs/NN-phase/README.md`; last step: the end-to-end walkthrough | Confirm costly actions; follow the README section and confirm |

### 7.4 Structure

```text
docs/
  principles.md       # project principles
  decisions/          # ADRs of the whole project
specs/
  NN-phase-name/
    plan.md           # the phase
    README.md         # how to verify each step and the phase (updated on every step)
    NN-step-name/
      spec.md         # the step
```

A revised decision is not rewritten: a new ADR supersedes it, and the old one is marked as superseded.
