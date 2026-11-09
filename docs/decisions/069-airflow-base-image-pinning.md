# D-069 — Airflow Base Image Pinning

Status: Accepted
Date: 2026-11-09
Phase: specs/04-orchestration-airflow

## Context

The Dockerfile names its base as `apache/airflow:3.4.0`. A tag is a label its publisher can later
move to a new build; a digest (`@sha256:...`) names one exact build and never changes. For Spark,
[D-051](051-spark-base-image.md) pinned the base by tag and digest. The Docker docs say pinning to a
digest guarantees "the same image version, even if a publisher replaces the tag with a new image";
without it, a rebuild may produce a different image, but you get the publisher's security fixes
automatically. The `3.4.0` tag (Python 3.13) currently points to digest `sha256:a8d9d19c…`.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Tag and digest: `apache/airflow:3.4.0@sha256:a8d9d19c…` | Best practice: the Docker docs say pinning to a digest is how "to fully secure your supply chain integrity" | Updating the base means changing the digest by hand | None | Same as D-051 (Spark) |
| B. Tag only: `apache/airflow:3.4.0` | Accepted practice: the Docker docs call versioned tags common, but "you're not guaranteed to get the same for every build" | No digest to maintain | None | Differs from D-051 |

## Decision

- **Recommended:** A, because it is the Docker best practice for reproducible builds and repeats
  D-051; updating the digest by hand is also when you choose to take the publisher's fixes.
- **Chosen:** A
- **Reason:** follows the recommendation. Dependabot, which the Docker docs suggest to propose digest
  updates, was not adopted: digest updates stay manual.

## Sources

- [Docker: building best practices (pin base image versions)](https://github.com/docker/docs/blob/main/content/manuals/build/building/best-practices.md)
- [Docker Hub: `apache/airflow` tags (digests)](https://hub.docker.com/r/apache/airflow/tags?name=3.4.0)
