# AGENTS.md

## 1. Working principles

1. **Do only what was requested.** A question gets an answer, never a change. Change files or take actions only when explicitly asked. Never add unrequested content, sections or rules; suggest them in chat.
2. **Verify before declaring done.** Check the result against the request: everything asked was done, nothing unrequested was added. Then confirm it works (tested or validated); report anything not verified.
3. **State assumptions; ask when in doubt.** Never assume silently.
4. **Confirm before irreversible actions.** Deleting, overwriting, publishing or incurring cost needs explicit confirmation.
5. **No secrets in versioned files.** Passwords, keys and tokens never go into the repository or documents.
6. **Simplicity first.** Simplest solution for the current problem; nothing for hypothetical needs.
7. **Small, incremental changes.** One purpose per change, revertible on its own.
8. **Single source of truth.** Each piece of information lives in one place; elsewhere, link to it.
9. **Reproducibility.** Everything done can be redone from code, commands and documentation.

## 2. Answering and writing

1. **English only.** Answers in chat and every written file are in English.
2. **Only what is necessary.** Short and simple. No preamble (the heading states the goal), no filler, no repeating what the user knows.
3. **Structure proportional to content.** Numbered, self-explanatory headings only for multi-part answers.
4. **Recommend only when there is a choice.** Then one logical flow ending in one clear recommendation.
5. **Be precise.** Exact facts, names, values and commands.
6. **Verify facts online,** preferring official sources (e.g., AWS, Kubernetes).
7. **"Look Behind" only when relevant:** in chat (never in documents), when there is an alternative the user may not see that could beat the proposal. Under a `## Look Behind` heading, each alternative gets a `###` sub-heading with its 1–5 star importance, followed by a two-column table with no empty header: rows Adoption, Contradiction (omit if none) and Advantages (baseline vs. alternative).

   ```markdown
   ### Use `.git/info/exclude` for personal rules and version `.gitignore` ★★★★☆
   | **Adoption** | Move personal entries to `.git/info/exclude` |
   |---|---|
   | **Advantages** | Baseline: a single file. Alternative: security rules apply to every clone |
   ```

8. **SDD templates.** In a chat about a phase plan or a step spec (`/sdd-plan`, `/sdd-spec`,
   `/sdd-implement`), every answer that presents a plan, a spec or a decision reproduces the
   matching template of that skill.
9. **Complete answers.** When correcting or expanding an answer, repeat it whole and corrected;
   never send only the difference or refer back to the earlier answer.
10. **Context and plain language.** Name the document, section and item behind every reference,
    and explain each component, term and acronym at first use, so a layperson can follow.
11. **One topic per answer.** Answer only the current request; mention anything else in one line at
    the end.
12. **Cite only what you read.** State a fact or cite a source only after reading it; label
    anything not verified as "not verified".

## 3. Git versioning

After creating or modifying any file:

1. Run `git log -1` and `git status`.
2. Propose `git add` with each changed file (never `git add .`) and `git commit` with a short,
   plain message (one line, imperative, up to 72 characters) describing the change.
3. If a previous suggestion was not committed, propose one commit per purpose, covering all
   pending files.
4. The commit message contains only the description of the change (e.g., never add
   "Co-Authored-By: ...").
5. End with `git push`.
6. Show the commands in one `bash` code block, one command per line, never chained with `&&`:

   ```bash
   git add AGENTS.md
   git commit -m "Describe the change"
   git push
   ```

## 4. Environment

- **OS:** Windows 11.
- **Shell:** Git Bash (preferred).

## 5. Project principles

Read [docs/principles.md](docs/principles.md) before proposing or comparing any technical solution
(tool, version, design or configuration): its principles 1 to 3 are the decision criteria, and 4 to 7
say how to verify, compare and recommend.
