[How to Run](../../HOW_TO_RUN.md) › 05 — Lab state: [Run](HOW_TO_RUN.md) | **Verify**

# 05 — Lab State Between Environments: How to Verify

Labs continue where they stopped: `down.sh` saves the state of every database with Velero and
`up.sh` brings it back in the new cluster, while the S3 buckets survive the teardown. Every check of
this phase is automated and run by the agent; this page records them. The end-to-end verification
proves the phase [Done When](plan.md#done-when).

## Prerequisites and Access

- [How to Run, 2. Prerequisites](../../HOW_TO_RUN.md#2-prerequisites)
- [How to Run, 4. Access](../../HOW_TO_RUN.md#4-access): the services this phase uses

## Step Verification

### 05.01 — Roadmap

No manual check: this step only updates the roadmap in [README §3](../../README.md#3-phases)
([spec](01-roadmap/spec.md)).

### 05.02 — Persistent Data Root

No manual check: every check is automated and was run by the agent
([spec, Verification Plan](02-persistent-data-root/spec.md#verification-plan)). Expected results:
`./scripts/up.sh` creates the five `eks-for-data-*` buckets (bronze, silver, Airbyte, Airflow,
Velero), and after `./scripts/down.sh` the bronze and silver files are still there while no EKS
cluster, NAT Gateway or VPC is left.

## End-to-End Verification

Written on the last step.

## Teardown

The whole environment: [How to Run, 5. Teardown](../../HOW_TO_RUN.md#5-teardown). Each step's own
teardown is in its spec:

- [05.01 — Roadmap](01-roadmap/spec.md#teardown)
- [05.02 — Persistent Data Root](02-persistent-data-root/spec.md#teardown)
