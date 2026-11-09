# D-060 — How the `silver` Catalog Is Created in Polaris

Status: Accepted
Date: 2026-11-09
Phase: specs/03-processing-spark-iceberg

## Context

The warehouse on silver is a Polaris catalog: the named container for Iceberg tables, with a storage
configuration (base location `s3://eks-for-data-silver-283429977024/` and the role
`eks-for-data-silver-data` that Polaris assumes to vend credentials,
[D-049](049-silver-storage-credentials.md)). It is created once, after the realm bootstrap
([D-059](059-polaris-realm-bootstrap.md)), by calling Polaris's management API with the root
credentials, from the user's computer through `kubectl port-forward`
([D-012](012-cluster-and-ui-access.md)). The choice is the client that makes the call.

The Polaris CLI (`apache-polaris` 1.8.0 on PyPI) needs Python 3.10 to 3.14; Python 3.13.7 is
installed on the user's computer.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. Polaris CLI: `polaris catalogs create` with the storage options, documented in the README | Best practice: the method in the Polaris "Creating a Catalog" guide | `pip install apache-polaris`, then one command | None | Same manual, documented flow as D-059 |
| B. Polaris CLI: `polaris setup apply` with a YAML file in Git describing the catalog | Accepted practice: a documented CLI command, not the one the catalog guide shows | Same install; one command plus one file to keep | None | The catalog settings live in Git |
| C. `curl`: request a token, then `POST /api/management/v1/catalogs` with a JSON body | Accepted practice: the official management API, called directly | Nothing to install; two commands with JSON | None | Same manual, documented flow as D-059 |

## Decision

- **Recommended:** A, because it is the method of the official guide and needs only one command with
  readable options.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Polaris 1.8.0: Creating a Catalog (CLI example)](https://github.com/apache/polaris/blob/apache-polaris-1.8.0/site/content/in-dev/unreleased/getting-started/creating-a-catalog/_index.md)
- [Polaris 1.8.0: Command Line Interface (`catalogs create`, `setup apply`)](https://github.com/apache/polaris/blob/apache-polaris-1.8.0/site/content/in-dev/unreleased/command-line-interface.md)
- [PyPI: `apache-polaris`](https://pypi.org/project/apache-polaris/)
- [Polaris management API spec](https://github.com/apache/polaris/blob/main/spec/polaris-management-service.yml)
