# D-055 — How the Spark Image Is Built and Published

Status: Accepted
Date: 2026-11-07
Phase: specs/03-processing-spark-iceberg

## Context

[D-047](047-spark-dependencies.md) chose a public image on `ghcr.io`, built by GitHub Actions. The
user does not want GitHub Actions. This decision chooses who builds and pushes the image; the
registry stays `ghcr.io`. Pushing from outside Actions requires a GitHub personal access token
(classic) with `write:packages`, kept outside the repository.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Build and push from the user's computer (`docker build`, `docker push`) | Common for personal projects; the build depends on the machine | Two documented commands; Docker 29.3.1 already installed (x86, as the nodes need) | Free; uploads about 1.5 GB (estimate) | Reproducible from documented commands |
| B. Build inside the EKS cluster (a BuildKit pod) | Used in platforms without CI; more parts to run | A build pod, a Secret with the token, and the cluster turned on | Node time during the build | One more component on the three clouds |
| C. Keep GitHub Actions (D-047) | Market practice: the same clean build every time, from Git | One workflow file | Free for public repositories | As planned; ruled out by the user |

## Decision

- **Recommended:** A. C ranks higher on best practice but was ruled out; A is much simpler than B,
  and its weakness is covered by the digest-pinned base ([D-051](051-spark-base-image.md)) and the
  fixed jar versions ([D-052](052-aws-sdk-jars.md)).
- **Chosen:** A
- **Reason:** the user does not want GitHub Actions; among the rest, follows the recommendation.
  Supersedes the "built by GitHub Actions" part of D-047; the `ghcr.io` registry stays.

## Sources

- [GitHub: Working with the Container registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
