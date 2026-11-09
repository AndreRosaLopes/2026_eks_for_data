# D-053 — Location of the Spark Image Dockerfile

Status: Accepted
Date: 2026-11-07
Phase: specs/03-processing-spark-iceberg

## Context

The Dockerfile is the file that describes how to build the Spark image. Where it goes changes nothing
in how the image works; it only organizes the repository. The repository root today, and where the
Dockerfile would go in each alternative:

```text
2026_eks_for_data/
├── infra/aws/            # Terraform (AWS only)
├── platform/aws/         # Kubernetes manifests (AWS only)
├── pipelines/            # data code
├── images/spark/         # A: new folder at the root
└── platform/
    ├── images/spark/     # B: new folder inside platform/
    └── aws/spark/        # C: inside the AWS folder
```

The same image will be used on AWS, Azure and GCP ([D-047](047-spark-dependencies.md)), while
everything under `aws/` is for AWS only.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. `images/spark/` | Common layout | New folder at the root | None | README §6 splits the repo into platform and pipelines; this is neither |
| B. `platform/images/spark/` | Common layout | New folder inside `platform/` | None | It is platform (README §6) and outside `aws/`, as the image serves all three clouds |
| C. `platform/aws/spark/` | Common layout | No new top-level folder | None | Puts an image for all three clouds inside the AWS-only folder |

## Decision

- **Recommended:** B, because it is the only option that is both under platform and outside `aws/`.
- **Chosen:** B
- **Reason:** follows the recommendation.

## Sources

- `README.md` §6 ("Change Separation")
- Repository folders (`git ls-files`)
