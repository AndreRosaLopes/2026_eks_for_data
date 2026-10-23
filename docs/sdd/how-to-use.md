# How to Use SDD

A short, practical guide. Concepts, skills and folder structure are in
[README, section 7](../../README.md#7-development-process-sdd).

## 1. Commands, in Order

```text
/sdd-plan <phase idea>       # once per phase
/sdd-spec 01.01              # then, for each step of the plan, in order:
/sdd-implement 01.01         #   specify, then implement
/sdd-spec 01.02
/sdd-implement 01.02
...
```

Each skill stops if its input is not approved: `/sdd-spec` needs an approved plan, and
`/sdd-implement` needs an approved spec.

## 2. Statuses

| Document | Flow |
|---|---|
| `specs/NN-phase/plan.md` | `Approved` → `Done` (after the last step) |
| Step, in the plan's "Steps" table | `To do` → `In progress` (spec approved) → `Done` (step verified) |
| `specs/NN-phase/NN-step/spec.md` | `Approved` → `Implemented` |
| `docs/decisions/NNN-name.md` | `Accepted` → `Superseded by D-NNN` (never rewritten) |

## 3. Your Part at Each Stage

| Stage | You |
|---|---|
| `/sdd-plan` | Answer one question per decision; nothing is saved until all are answered |
| `/sdd-spec` | Approve the spec proposed in chat. A new choice between alternatives goes back to the plan first |
| `/sdd-implement` | Run or confirm costly actions (e.g., `terraform apply`); approve any divergence from the spec (spec and ADR are updated in the same change); follow the step's section in the phase README and confirm |
| After every file change | Review the proposed commit ([AGENTS.md, section 3](../../AGENTS.md#3-git-versioning)) and ask for it to be applied |

If an automated check fails, the agent reports it and stops; nothing is closed until it passes.
