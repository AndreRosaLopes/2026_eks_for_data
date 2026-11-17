# D-084 — Snapshot Controller Add-on Version

Status: Accepted
Date: 2026-11-17
Phase: specs/05-lab-state-persistence

## Context

Velero ([D-076](076-lab-state-persistence.md)) asks Kubernetes to snapshot each database volume; the
snapshot controller carries out these requests. EKS Auto Mode does not include it, so it is installed
as the `snapshot-controller` EKS add-on (an AWS-managed install) in `infra/aws/cluster`. The
`terraform-aws-modules/eks` module defaults to `most_recent = true`: with no version given, it
installs the newest version at each apply. For Kubernetes 1.36 that is `v8.7.0-eksbuild.4`, also
the AWS default.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Pin `addon_version = "v8.7.0-eksbuild.4"` | No official best practice (checked: AWS snapshot controller page, EKS module variables) | One line to keep up to date | Zero | Same as every other pin in the repo (EKS module, Argo CD chart, Kubernetes 1.36) |
| B. Module default: newest version at each apply | No official best practice (same sources) | No version to maintain | Zero | A new `up.sh` run can install a different version |

## Decision

- **Recommended:** A. With no official best practice, principle 2 (simplicity) decides: a fixed
  version makes every bring-up the same, and follows the pinning used everywhere else.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Amazon EKS: enable snapshot functionality for CSI volumes](https://docs.aws.amazon.com/eks/latest/userguide/csi-snapshot-controller.html): recommends the managed add-on; Auto Mode does not include the controller
- `aws-mcp`, EKS `DescribeAddonVersions` (`snapshot-controller`, Kubernetes 1.36, us-east-1): newest is `v8.7.0-eksbuild.4`, also the default, supports `auto` compute
- `infra/aws/cluster/.terraform/modules/eks/variables.tf`: `most_recent = optional(bool, true)`
