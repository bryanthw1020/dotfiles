---
name: persist-artifacts
description: Use when planning a multi-step or multi-file change, recording an architecture decision, writing a review, post-mortem, or handoff, tracking a multi-step task list, or writing a feature spec or contract. Persists plans, reviews, ADRs, and specs in the repository in one portable, agent-neutral format.
---

# Persistent Workspace Artifacts

## 1. When to persist

Write an artifact to the repository when you plan a multi-step or multi-file change, record an architecture decision, write a review/post-mortem/handoff, track a multi-step task list, or write a feature spec/contract.

The repository is the source of truth. Never keep the only copy in chat, agent memory, scratch directories, or tool-specific plan stores.

If the repository defines its own artifact convention, follow the repository-specific rule.

## 2. Layout and naming

Paths are relative to the repo root.

| Artifact | Directory | File name |
| --- | --- | --- |
| Plan | `docs/artifacts/` | `YYYYMMDDHHmmss-<topic>-plan.md` |
| Review / post-mortem | `docs/artifacts/` | `YYYYMMDDHHmmss-<topic>-review.md` |
| Task list | `docs/artifacts/` | `YYYYMMDDHHmmss-<topic>-tasklist.md` |
| ADR | `docs/adr/` | `NNNN-<decision-title>.md` |
| Spec / contract | `docs/specs/` | `<feature-name>-spec.md` |

- Timestamp is UTC creation time: `date -u +%Y%m%d%H%M%S`. Never use local time. Never rename an artifact after creation; to replace it, create a new one and supersede the old one.
- `<topic>`, `<decision-title>`, `<feature-name>`: lowercase ASCII kebab-case, no spaces/slashes, no date.
- `NNNN`: zero-padded, increasing ADR number. Never reuse a number, even after supersession.
- Before writing, check the target path is free (use exclusive create if available). Taken ADR number: use the next free one. Taken timestamped path: pick a more specific topic. Never overwrite.
- Create directories as needed. Commit artifacts with the work; never gitignore them.

Example: `docs/artifacts/20261024010059-offline-tile-caching-plan.md`

## 3. Frontmatter (artifacts only)

YAML frontmatter must be the first bytes of the file: no BOM, blank line, or comment before it.

```yaml
---
title: Offline Tile Caching Plan
date: 2026-10-24
status: proposed
author: claude
tags: [maps, caching, performance]
---
```

| Key | Rule |
| --- | --- |
| `title` | Human-readable; closely match the `#` heading. |
| `date` | UTC creation date `YYYY-MM-DD`. Never change on update. |
| `status` | One of: `proposed` (drafted, not approved/started), `in_progress`, `completed` (plan executed / review closed / ADR accepted / spec approved), `superseded` (replaced, or work stopped by a recorded decision). |
| `author` | One of: `claude`, `antigravity`, `opencode`, `kilocode`, `human`. Use the author of the current revision; note other contributors in the body. A new agent adds its lowercase product name to this list in the same change. No display names or versions. |
| `tags` | YAML list of lowercase kebab-case strings; `[]` if none. |
| `superseded_by` | Required when `superseded`: repo-relative path to the replacement, or to a review artifact recording why work stopped. Never leave it empty. |
| `supersedes` | Recommended on a replacement: path of the artifact it replaces. |
| `related` | Optional list of repo-relative paths. |

- Transitions: `proposed` → `in_progress` → `completed`. Any status may become `superseded`. To reopen a `completed` artifact, set `in_progress` and add a dated note explaining why.
- Quote strings containing `:`, `#`, `[`, `]`, or a leading `*`.
- No tool-specific keys, personal emails, or locale-specific dates.

## 4. Workflow

1. **Check first.** Before a non-trivial task, search `docs/artifacts/`, `docs/specs/`, `docs/adr/` by topic and tag (not only filename). Update an existing artifact instead of duplicating it. If it is `superseded`, follow `superseded_by` first. If two artifacts cover one topic, reconcile into one and supersede the other (or link both and mark one primary). A `completed` artifact stays authoritative for its scope; a new phase gets a new artifact linked via `related`.
2. **Plan in the repo.** For multi-step or multi-file work, create or update `docs/artifacts/YYYYMMDDHHmmss-<topic>-plan.md`. Steps are verifiable GFM checkboxes (`- [ ]` / `- [x]`). Include a `Verification` section stating how completion is checked.
3. **Keep status current.** Check off finished items and update `status` as work moves. Do not mark a plan `completed` while unchecked items remain unless they are listed as out of scope.
4. **Leave a resumable handoff.** The artifact must be understandable without the chat: record decisions, assumptions, open questions, and the exact next step.

## 5. Content rules

- **Portable only:** GitHub-Flavored Markdown, standard YAML frontmatter, and fenced `mermaid` diagrams. No vendor directives, custom XML tags, mention syntax, plan-store links, or UI-specific syntax. It must read correctly in a plain Markdown renderer.
- **Non-destructive:** Never delete a superseded artifact. Do not rewrite an old ADR to hide a reversed decision; write a new ADR and link both. Preserve other authors' work: append or merge, and disagree with a dated note or a new artifact.
- **Links:** Repo-relative only (e.g. `../adr/0007-use-postgres.md`). No `file://`, absolute home paths, chat links, or tool-specific URLs.
- **No secrets or personal data:** Artifacts are committed. Use placeholders for credentials, tokens, customer data, and private URLs.
- **Write for a new contributor:** Define acronyms on first use, avoid chat shorthand, and prefer stable headings: `Context`, `Decision`, `Consequences`, `Steps`, `Verification`, `Open Questions`.
