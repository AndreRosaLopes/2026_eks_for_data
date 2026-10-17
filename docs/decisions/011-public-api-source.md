# D-011 — Public API Source

Status: Accepted
Date: 2026-10-17
Phase: specs/01-ingestion-airbyte-s3

## Context

The phase needs a public API as the Airbyte source, with no secrets.

Discarded: **source-faker**, because it generates synthetic data and does not read an API.

## Alternatives

| Alternative | Best Practices | Simplicity | Cost | Consistency with the Whole |
|---|---|---|---|---|
| A. PokeAPI (`source-pokeapi`) | No authentication, ready connector (Marketplace); minimal volume: one stream, one record per configured Pokémon | Simplest | Zero | No secrets |
| B. Custom declarative (low-code) connector for an open API | More realistic data | Requires a YAML manifest | Zero | Meets all requirements |

## Decision

- **Recommended:** A, because it proves the flow to Parquet with the least effort; a richer
  source can come in a later phase.
- **Chosen:** A
- **Reason:** follows the recommendation.

## Sources

- [Airbyte: PokeAPI source](https://docs.airbyte.com/integrations/sources/pokeapi)
