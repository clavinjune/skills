---
name: grilling
description: "Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases."
---

Interview me relentlessly about every aspect of this until we reach a shared understanding. Walk down each branch of the decision tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time, waiting for feedback on each question before continuing. Asking multiple questions at once is bewildering.

If a *fact* can be found by exploring the environment (filesystem, tools, etc.), look it up rather than asking me. The *decisions*, though, are mine — put each one to me and wait for my answer.

Do not act on it until I confirm we have reached a shared understanding.

## Documenting the outcome as an ADR

When shared understanding is reached, **offer** (never auto-write): "We've reached agreement — want me to write this up as an ADR?" Skip the offer if the session ended in a dead idea or a trivial conclusion.

If accepted, write a classic Nygard-style ADR:

- **Status** (accepted), **Context**, **Decision**, **Consequences**, plus **Rejected alternatives** — capture the branches walked during grilling and *why* each lost. This is the core value of the session.

Location is context-dependent:

- **Project/codebase decision** → `docs/adr/NNNN-title.md` in that repo (next sequential number).
- **Personal/life/career decision or general discussion** → your notes vault (e.g. an Obsidian
  vault or journal directory), as a dated note linking back to that day's entry. Adapt the exact
  path/filename convention to whatever note-taking system you use.
