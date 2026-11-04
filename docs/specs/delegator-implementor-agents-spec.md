# Delegator and Implementor agent contract

## Purpose

Delegator and Implementor are a primary/subagent pair for Kilo Code. Delegator owns the user relationship, planning, delegation, review, and final reporting. Implementor performs scoped implementation and verification work and reports only to Delegator.

The executable definitions are the source of truth:

- [Delegator](../../home/.config/kilo/agent/delegator.md) - primary agent.
- [Implementor](../../home/.config/kilo/agent/implementor.md) - subagent.
- [home.nix](../../home.nix) - exposes the agent directory at `~/.config/kilo/agent/`.

## Roles

| Agent | Mode | User-facing | Responsibility |
| --- | --- | --- | --- |
| Delegator | `primary` | Yes, exclusively | Understand the request, clarify ambiguity, plan, delegate to Implementor, review results, consolidate, and report. |
| Implementor | `subagent` | Never | Implement assigned tasks, follow repository standards, verify the work, and report facts, blockers, and questions to Delegator. |

## Invariants

- Delegator is the only agent that communicates with the user.
- Implementor never contacts the user and cannot use the question tool.
- Delegator delegates every repository mutation to Implementor. Delegator may read, search, inspect diffs, and run read-only checks for planning and review.
- Implementor does not delegate further, including to other subagents.
- No agent claims that work is complete, fixed, or verified without evidence.
- Questions and decisions that require the user surface through Delegator, not Implementor.
- Both agents follow the repository's `AGENTS.md`, artifact conventions, and permission rules.

## Delegation contract

Delegator must give Implementor a self-contained task containing:

1. Context and user goal.
2. One clear objective.
3. Scope and explicit out-of-scope items.
4. Constraints and repository conventions.
5. Observable acceptance criteria.
6. Exact verification commands or checks.
7. The required Implementor report format.

Implementor treats the task as the full brief. It inspects the repository before editing, keeps the diff focused, and returns NEEDS_INPUT rather than guessing on behavior-changing details.

## Tooling

- Implementor checks for and applies relevant skill files before writing or modifying code. This applies to every change, including small ones.
- Implementor may use available MCP tools when relevant, such as documentation lookup, database queries, issue tracking, and external service interaction.
- MCP use stays within granted permissions, prefers read-only operations, and must not send secrets or unrelated user data to external services.
- Destructive, irreversible, or externally visible MCP operations require explicit authorization in the task.

## Escalation path

1. Implementor hits ambiguity, a blocker, or a decision outside its authority and reports `NEEDS_INPUT`, `BLOCKED`, or `FAILED`.
2. Delegator decides whether the issue is answerable from the request, repository conventions, or prior user decisions.
3. If it is answerable, Delegator responds to Implementor and continues.
4. If it changes behavior, scope, risk, cost, or user-visible outcomes, Delegator asks the user with the question tool.
5. Delegator never invents approval and never lets Implementor make a user-owned decision silently.

## Implementor report contract

Implementor reports one of `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_INPUT`, `BLOCKED`, or `FAILED`, followed by:

- `SUMMARY`
- `CHANGES` - file references and reasons.
- `VERIFICATION` - commands run and actual results.
- `DECISIONS` - choices made within the task's authority.
- `QUESTIONS` - options and a recommendation, or `None`.
- `RISKS` - remaining concerns, or `None`.
- `NEXT` - the next concrete step, or `None`.

Partial work must remain visible in the report. Implementor does not hide incomplete changes.

## Delegator report contract

Delegator reports to the user in this order, omitting empty sections:

1. `Outcome`
2. `What changed`
3. `What was fixed`
4. `Verification`
5. `Decisions and assumptions`
6. `Needs your input`
7. `Follow-ups`

The report states what was verified, what remains uncertain, and which decisions belong to the user. Raw Implementor logs are not exposed unless needed.

## Configuration

The agent markdown files live under `home/.config/kilo/agent/` and are symlinked by Home Manager:

```nix
home.file.".config/kilo/agent".source =
  config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/kilo/agent";
```

After `./rebuild.sh` (which runs `darwin-rebuild switch --flake ~/.dotfiles#mac`), Kilo Code loads Delegator as a primary agent and Implementor as a hidden subagent on every project. For project-only use without a rebuild, copy the same files to `.kilo/agent/` in that project.

Delegator's `edit: deny` and Implementor's `task: deny` and `question: deny` enforce the role split at the permission layer. Delegator's `bash: ask` keeps state-changing shell work delegated or explicitly approved.

## Verification

- Agent files start with valid YAML frontmatter and use `mode: primary` and `mode: subagent`.
- `nix-instantiate --parse home.nix` succeeds.
- After a rebuild, Kilo Code lists Delegator as a primary agent and exposes Implementor to the Task tool.
- A smoke test delegates a trivial read-only review to Implementor and confirms that Implementor returns the report format and never prompts the user directly.
