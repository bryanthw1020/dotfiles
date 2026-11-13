# Delegator and Subagent Architecture Contract

## Purpose

Delegator and its subagents form a primary/specialist hierarchy for Kilo Code (with parallel agent definitions for Antigravity). Delegator owns the user relationship, intake, requirements confirmation, planning, delegation, report validation, and final reporting. Specialized subagents perform read-only discovery, research, independent test/code review, implementation, and stack-specific unit testing, reporting only to Delegator.

The executable definitions are the source of truth:

- [Delegator](../../home/.config/kilo/agent/delegator.md) - primary orchestrator agent.
- [Researcher](../../home/.config/kilo/agent/researcher.md) - read-only research, MCP/web investigation, and independent `REVIEW` / `TEST_REVIEW` subagent.
- [Implementor](../../home/.config/kilo/agent/implementor.md) - production code, configuration, docs, migrations, runner setup, and non-specialist/E2E test subagent.
- [test-laravel](../../home/.config/kilo/agent/test-laravel.md) - PHP and Laravel unit-testing specialist (`>= 80%` coverage).
- [test-js-ts](../../home/.config/kilo/agent/test-js-ts.md) - standalone JavaScript and TypeScript unit-testing specialist (`>= 80%` coverage).
- [test-react-nextjs](../../home/.config/kilo/agent/test-react-nextjs.md) - React and Next.js unit-testing specialist (`>= 80%` coverage).
- [test-vue-nuxt](../../home/.config/kilo/agent/test-vue-nuxt.md) - Vue 3 and Nuxt unit-testing specialist (`>= 80%` coverage).
- [kilo.jsonc](../../home/.config/kilo/kilo.jsonc) - Kilo global permissions, MCP servers, and `default_agent: "delegator"`.
- [home.nix](../../home.nix) - symlinks `~/.config/kilo/agent/`, `~/.config/kilo/kilo.jsonc`, and `~/.kilo/rules`.

## Roles

| Agent | Mode | User-facing | Responsibility |
| --- | --- | --- | --- |
| Delegator | `primary` | Yes, exclusively | Intake, confirm requirements, plan (`todowrite`), route tasks, track Run State, enforce quality/review gates, consolidate, and report. |
| `explore` (built-in) | `subagent` | Never | Fast, bounded read-only repository lookup, extension/import detection, and read-only structural checks. |
| `researcher` | `subagent` (`hidden: true`) | Never | Multi-step investigation, web/MCP research, option comparison, command-backed `REVIEW`, and mandatory `TEST_REVIEW` of `test-*` commits. |
| `implementor` | `subagent` (`hidden: true`) | Never | Production code, config, migrations, documentation, repo artifacts, runner/coverage setup, E2E/integration tests, and uncovered-stack unit tests. |
| `test-laravel` | `subagent` (`hidden: true`) | Never | PHP/Laravel unit tests (including `tests/Feature/` HTTP/console isolation tests) using PHPUnit/Pest with PCOV/Xdebug (`>= 80%`). |
| `test-js-ts` | `subagent` (`hidden: true`) | Never | Standalone `.js`/`.ts` unit tests using Vitest/Jest and strict `tsc` (`>= 80%` Stmts/Branch/Funcs/Lines). |
| `test-react-nextjs` | `subagent` (`hidden: true`) | Never | React/Next.js component, hook, Server Action, Route Handler, and middleware unit tests using RTL + Vitest/Jest (`>= 80%`). |
| `test-vue-nuxt` | `subagent` (`hidden: true`) | Never | Vue 3/Nuxt SFC, composable, Pinia, and Nitro server unit tests using Vitest + `@vue/test-utils`/`@nuxt/test-utils` (`>= 80%`). |

## Invariants

- Delegator is the sole user interface; subagents never contact the user and have `question: deny`.
- Delegator never executes `bash` commands, edits files, writes tests, calls MCP tools, or reads/searches/lists repository files (`edit`, `bash`, `grep`, `glob`, `list`, `semantic_search`, `webfetch`, `websearch` denied; `read` omitted from denial only to avoid `TaskTool` inheritance leaks).
- All write-capable tasks (`implementor`, `test-*`) run sequentially on a single non-default git branch recorded in `ISOLATION` (reusing an existing non-default branch, or creating the fallback branch slug from `main`/`master`). Never commit to `main` or `master`.
- Requirements Gate: bounded read-only `explore` and unambiguous read-only `researcher` discovery may run immediately; no write-capable task (`implementor`, `test-*`), externally mutating MCP action, or ambiguous multi-option `researcher` task starts until the user confirms `GOAL`, `ACCEPTANCE`, `INVARIANTS`, and `CONSTRAINTS`.
- Subagents never spawn further subagents (`task: deny`).
- No agent claims work is complete, fixed, or verified without evidence lines from verified command execution.
- Unit tests for PHP/Laravel, JS/TS, React/Next.js, and Vue/Nuxt always route to their matching `test-*` specialist; `test-*` specialists never modify production source code or runner/package configs.
- Every agent follows `AGENTS.md`, `restricted-files.md`, artifact conventions (`persist-artifacts` assigned to `implementor`), and permission rules.

## Delegation contract and context handoff

Delegator uses role-scoped task prompts (target `<= 300` words unless a specification is required):

1. Header: `AGENT`, `REPORT PROFILE` (`INVESTIGATE`, `REVIEW`, or `IMPLEMENT`), `ISOLATION` (write agents only), `SKILLS` (`implementor`, `test-*`, and `researcher` `REVIEW`/`TEST_REVIEW`), and `DELTA` (resumed `task_id` follow-ups after cross-agent edits).
2. Role-specific handoff inputs:
   - `explore` -> `implementor`: compact `FINDINGS` (`path:line`), repository conventions, and `DIRTY_BASELINE`.
   - `implementor` -> `test-*`: modified/created `path:line` symbols, `EXPECTED INVARIANTS` derived from confirmed `ACCEPTANCE`, `BRANCH`/`COMMIT`, and `DIRTY_BASELINE`.
   - `test-*` -> `researcher` (`TEST_REVIEW`): `BRANCH`/`COMMIT`, target source/test paths, `EXPECTED INVARIANTS`, and claimed `COVERAGE`/`VERIFICATION` results.
3. Scope, constraints, acceptance criteria, exact verification commands, and return contract (`explore` prompts embed `INVESTIGATE` or `REVIEW` without `.tool-output/kilo/` write demands).
4. Evidence handles (`implementor` and `test-*` only): large outputs go to `.tool-output/kilo/<task>-<timestamp>.log` (never staged or committed) with path, `sha256`, and a 3-line excerpt.

## Five-layer verification strategy for `test-*` outputs

To ensure generated unit tests are free of hallucinated assertions, weakened assertions, or stubbed-out SUT logic:

1. **Oracle-first delegation:** Delegator passes `EXPECTED INVARIANTS` into `test-*`. If observed SUT behavior contradicts an invariant, `test-*` must never alter assertions to match buggy code; it reverts unverified edits, stops with `BLOCKED`, and reports the production defect (`path:line`, expected vs. actual) for `implementor` to fix.
2. **Tool-layer containment & complete metrics:** `test-*.md` denies edits to production/config files in frontmatter, requires `>= 80%` across all reported coverage metrics (`Stmts`, `Branch`, `Funcs`, `Lines` / `Lines`, `Methods`), and requires `0 failed / 0 skipped / 0 incomplete / 0 todo`.
3. **Mandatory independent `TEST_REVIEW` (`researcher`):** Every `test-*` commit is audited via `git show`/`git diff` by `researcher` against a 6-point checklist (`Purity`, `Anti-Bypass`, `SUT-Real`, `Assertions`, `Oracle`, `Independent Execution`) before Delegator accepts `DONE`.
4. **Red-First bug-fix proof & branch sensitivity:** Bug fixes record or verify a failing pre-fix reproduction check, and `TEST_REVIEW` verifies assertions cover conditional/error branches rather than merely executing lines.
5. **Stack-native static hygiene:** Existing repo rules (`expect-expect`, `no-conditional-expect`, `no-disabled-tests`, `no-floating-promises`, `phpstan-phpunit`) act as hard blockers when configured and guide `TEST_REVIEW` checks otherwise.

## Escalation, fallbacks, and run state

- `todowrite` tracks planned tasks (`T1`, `T2`, ...) in Kilo UI while Delegator maintains a compact Run State (`GOAL`, `ACCEPTANCE`, `INVARIANTS`, `CONSTRAINTS`, `ISOLATION`, `DIRTY_BASELINE`, `TASKS` with `task_id`, `CHANGES`, `CHECKS`, `DECISIONS`, `DEVIATIONS`, `OPEN`, `RISKS`, `NEXT`, `HANDLES`).
- Retry/bounce bounds: 1 reformat retry for non-compliant reports; max 2 attempts per subtask; max 2 `test-* <-> implementor` bug-fix bounces before escalating to the user.
- Non-`DONE` working-tree hygiene: if `implementor` or `test-*` stops without confirming `COMMIT: None (reverted unverified edits)`, Delegator verifies `git status --short` via `explore` or `researcher` before continuing.
- Missing coverage drivers, non-git workspaces, dirty target files, or unavailable MCP tools surface via `NEEDS_INPUT` / `BLOCKED` options at the Requirements Gate rather than silent workarounds.

## Subagent and Delegator report contracts

- `explore` returns `INVESTIGATE` or `REVIEW` (`<= 60` lines, `<= 400` words, no raw code/logs).
- `researcher` returns `INVESTIGATE` or `REVIEW` (including `TEST_AUDIT:` when reviewing `test-*` commits).
- `implementor` and `test-*` return `IMPLEMENT` (`STATUS`, `SUMMARY`, `BRANCH`, `COMMIT`, `SKILLS`, `COVERAGE` for `test-*`, `CHANGES`, `VERIFICATION` with pass/fail/skip counts, `DECISIONS`, `QUESTIONS`, `RISKS`, `NEXT`, `EVIDENCE`).
- Delegator projects the Run State into the user-facing report (`Outcome`, `What changed`, `What was fixed`, `Verification` including coverage and `TEST_REVIEW` verdict, `Deviations from the request`, `Where the work lives`, `Decisions and assumptions`, `Needs your input`, `Follow-ups`).

## Configuration & Verification

Agent markdown files live under `home/.config/kilo/agent/` (and Antigravity mirrors under `home/.gemini/config/agents/`) and are symlinked via [home.nix](../../home.nix). After `./rebuild.sh`:

- Agent files start with valid YAML frontmatter using `mode: primary` (`delegator`) and `mode: subagent` (`hidden: true` for subagents).
- `nix-instantiate --parse home.nix` succeeds.
- `kilo` lists `delegator` as the default primary agent with `orchestrator` disabled and exposes `explore`, `researcher`, `implementor`, `test-laravel`, `test-js-ts`, `test-react-nextjs`, and `test-vue-nuxt` to the Task tool.
