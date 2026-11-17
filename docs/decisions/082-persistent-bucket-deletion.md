# D-082 — Deleting the Persistent Buckets on Purge

Status: Accepted
Date: 2026-11-17
Phase: specs/05-lab-state-persistence

## Context

Phase objective: stop the labs at any point and resume them later from that same point.

Step 05.02 creates the Terraform root `infra/aws/data`, which holds the five buckets: bronze, silver,
Airbyte, Airflow and the Velero backups. `down.sh` keeps this root, and only the purge (a full reset
of the lab) destroys it. The Terraform setting `force_destroy` decides whether `terraform destroy`
deletes a bucket that still holds files (`true`) or stops with an error (`false`, the default).

How you resume the labs in each case:

| Case | A. `true` | B. `false` |
|---|---|---|
| Stop and resume (`down.sh`, then `up.sh`) | Resumes from where you stopped | Resumes from where you stopped |
| `destroy` run by mistake on `infra/aws/data` | Can't resume: the data is deleted, and the labs start from zero | Resumes: the destroy fails, and `terraform apply` puts back any setting it removed (not verified by a test) |
| Purge | One command; the labs start from zero | Empty the buckets, then `destroy`; the labs start from zero |

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. `force_destroy = true` | No official best practice: the provider and module docs only set the default (`false`) | The purge is one command | Same | Meets the objective |
| B. `force_destroy = false` | No official best practice: same docs | The purge must first empty the five buckets | Same | Meets the objective, and keeps the resume point after a mistaken destroy |

## Decision

- **Recommended:** A. Both let you stop and resume the labs. With no official best practice,
  principle 2 (simplicity) decides.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Terraform AWS provider: `aws_s3_bucket`, `force_destroy`](https://github.com/hashicorp/terraform-provider-aws/blob/main/website/docs/r/s3_bucket.html.markdown)
- [terraform-aws-modules/s3-bucket README, `force_destroy`](https://github.com/terraform-aws-modules/terraform-aws-s3-bucket/blob/master/README.md)
