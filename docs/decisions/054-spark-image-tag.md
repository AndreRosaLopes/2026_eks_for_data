# D-054 — Spark Image Tag

Status: Accepted
Date: 2026-11-07
Phase: specs/03-processing-spark-iceberg

## Context

The image is published as `ghcr.io/andrerosalopes/spark:<tag>`; the tag is the label after the
colon. The Spark jobs of steps 03.04 and 03.06 name the image by this tag, so the tag is how you know
which image a job runs. A tag can later be moved to point to a different image.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Version tag, e.g. `4.0.5-iceberg1.12.0` | Kubernetes recommends a meaningful tag such as `v1.42.0` | The tag says what is inside | None | Matches the versions of D-050 and D-052 |
| B. Git commit tag, e.g. `sha-3f9c2a1` | A new tag for every build | The tag says nothing about what is inside | None | Meets all requirements |
| C. `latest` | Kubernetes advises against it, because it hides which image is running and makes rollback hard | The jobs never need a tag change | None | Breaks reproducibility (AGENTS.md §1.9) |

## Decision

- **Recommended:** A, because it is the practice Kubernetes recommends and the tag says what is
  inside the image.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Kubernetes: Images](https://kubernetes.io/docs/concepts/containers/images/)
- [docker/metadata-action](https://github.com/docker/metadata-action)
