# Antigravity agent translation notes

This file records how the seven Kilo agent definitions in `home/.config/kilo/agent/`
(`delegator`, `researcher`, `implementor`, `test-laravel`, `test-js-ts`,
`test-react-nextjs`, and `test-vue-nuxt`) were translated into Antigravity custom
agents in `home/.gemini/config/agents/`. It lives outside `agents/` on purpose:
Antigravity parses every Markdown file in an `agents/` directory as an agent
definition.

The Kilo sources are unchanged. Nothing here is deployed to `~/.gemini/config/`
unless Home Manager links the directory.

## Tool names used, and why

Two tool-name sets exist in the local bundled material:

- `~/.gemini/antigravity-cli/builtin/skills/agy-customizations/docs/hooks.md` uses
  `view_file` and `run_command` as real matcher targets.
- `~/.gemini/antigravity-cli/builtin/skills/migrate-agent-settings/SKILL.md` maps
  Claude names to `read_file`, `edit_file`, `write_file`, `run_command`,
  `manage_task`, and `search_web`.

The 1.3.3 binary and its bundled changelog settle it in favor of the runtime tool
names:

- The model-facing guidance embedded in the binary says to use "specialized tools
  such as `grep_search`, `find_by_name`, `view_file`, `write_to_file`, `edit_file`,
  `multi_replace_file_content`, and `list_dir`".
- The changelog entry about the default toolset says `find_by_name`, `grep_search`,
  and `list_dir` were retired from the default baseline but remain "available to
  custom agents that explicitly list them in `tools`". That statement only makes
  sense if `tools` accepts those exact runtime names.
- `read_file` and `write_file` in the binary appear as permission-grant identifiers
  (`read_file(*)`, `write_file(<path>)`), not as agent tool names. The user's own
  `settings.json` uses `write_file(.git/)` as a permission rule.

Agents therefore use only these validated runtime tool names: `view_file`,
`write_to_file`, `edit_file`, `multi_replace_file_content`, `grep_search`,
`find_by_name`, `list_dir`, `run_command`, `search_web`, `read_url_content`,
`skill_search`, `ask_question`, `invoke_subagent`, `send_message`, `manage_inbox`,
`manage_subagents`, and `manage_task`. No name was invented.

Version note: the Homebrew cask path on this machine still says `1.3.3`, while the
language server reports `1.5.3`. The bundled docs, the `hooks.md` matcher table,
and the embedded changelog used to resolve these names are the ones shipped with
the installed binary (`~/.gemini/antigravity-cli/builtin/`).

## Feature mapping

| Kilo feature | Antigravity handling |
|---|---|
| `mode: primary` / `mode: subagent` | `mainAgent: true, subagent: false` for Delegator; `mainAgent: false, subagent: true` for Researcher, Implementor, and the four `test-*` specialists. |
| `hidden: true` | Kept; `hidden` is a supported Markdown agent key. |
| `color` | Dropped. Antigravity has no agent color key. |
| `model` pinned per agent | Sources pin none, so every agent uses `model: inherit`. |
| `permission` denylist | Converted to an explicit `tools` allowlist per agent, plus prose for the restrictions that a tool allowlist cannot express. |
| `permission` inheritance (the `edit: deny` exemption and write/MCP denies propagating into TaskTool child sessions) | No equivalent. Antigravity has no permission inheritance: each agent's `tools` allowlist is independent, and a deny is expressed by omitting the tool from that agent's list. Every agent must therefore be enumerated separately, and no parent deny is carried into a subagent. |
| Worktree/branch isolation rules | No Antigravity equivalent. Retained as body prose in `delegator.md`, `implementor.md`, and `test-*.md`; nothing in the runtime enforces them. |
| `permission.task` allowlist | Delegator gets `invoke_subagent`, `send_message`, `manage_inbox`, and `manage_subagents`. `define_subagent` is withheld because the source forbids creating subagents at runtime. |
| `task` subagent allowlist (`explore`, `researcher`, `implementor`, `test-laravel`, `test-js-ts`, `test-react-nextjs`, `test-vue-nuxt`) | `invoke_subagent` accepts any `TypeName`, so the allowlist cannot be enforced. Type scoping survives only as prose in the Delegator's routing rules. |
| `permission.edit: deny` and no direct repo/shell access on Delegator | Delegator has no `view_file`, `run_command`, `write_to_file`, `edit_file`, or `multi_replace_file_content`. |
| `permission.edit/write/notebook_*: deny` on Researcher | Researcher has no write, edit, or notebook tools. |
| `permission.bash` allow/deny patterns | Antigravity agent frontmatter has no per-command rule syntax. Delegator omits `run_command` entirely (`bash: deny` in Kilo); Researcher, Implementor, and `test-*` get `run_command` and state their allowed/forbidden commands in prose. |
| `permission.question` | Delegator gets `ask_question`; Implementor, Researcher, and the four `test-*` specialists do not, and their bodies state that it is unavailable. |
| `permission.todowrite` | No Antigravity todo tool exists. Delegator keeps its run-state block instead; the section is called out in the platform mapping. |
| `manage_task` granted to Implementor and `test-*` | No direct Kilo counterpart; Kilo denied `todowrite`. `manage_task` covers background and cron task management, not todo lists, so the todo denial is intact. |
| `permission.agent_manager` | No equivalent. Dropped; it only controlled Kilo's Agent Manager UI. |
| `permission.grep`/`glob`/`list`/`semantic_search` | No search, list, or semantic tools are granted to Delegator. |
| `permission.webfetch`/`websearch` | Delegator gets neither `read_url_content` nor `search_web`. Implementor, Researcher, and the four `test-*` specialists do. |
| `task` tool and `subagent_type` | Replaced by `invoke_subagent` with `TypeName`. Follow-ups use `send_message`; lifecycle uses `manage_subagents`. |
| Kilo's built-in `explore` agent | Antigravity has no `explore` agent. The Delegator's platform mapping states that every `explore` reference means the built-in `research` subagent (`TypeName: research`). Routing text is otherwise unchanged. |
| `skill` tool and `<available_skills>` | Replaced by `skill_search` plus prose. The `<available_skills>` tag was replaced with "the skills listed in your system prompt" because that block is Antigravity's own injected skill list. |
| MCP tool families (`github_*`, `playwright_*`, `rea_*`) | Rewritten as MCP tools granted with `mcp(<server>/<tool>)`, naming github, playwright, and rea only as examples. No MCP tool names are listed in frontmatter. |
| `.tool-output/kilo/` | Replaced with `.tool-output/antigravity/` in the current working directory (ignored via `.tool-output/` in `.gitignore`) so large evidence logs are saved via `write_to_file` without shell `>` redirection. |
| "new definitions load when Kilo restarts" | Reworded to "when Antigravity restarts". |
| `write`/`apply_patch` exemption notes in Delegator frontmatter | Removed with the permission block. The behavioral rule (no edits, no unit-test writing, no MCP calls) is preserved in Boundaries. |
| `mcpServers`, `skills`, `plugins` frontmatter keys | Not set. Agents inherit configured MCP servers, discover global skills, and rely on the existing plugin set. Setting `tools` already scopes access. |
| `commandExecutionPolicy` | Not set. The retained default keeps commands subject to the user's normal permission prompt rather than auto-running them. |

## Deliberate deviations

- Delegator omits both `view_file` and `run_command` so it never reads files or runs shell commands during Intake; all repository discovery and git branch preparation are delegated to subagents.
- Delegator's routing table and run-state block still use the names `explore`,
  `researcher`, `implementor`, `test-laravel`, `test-js-ts`, `test-react-nextjs`, and
  `test-vue-nuxt` so the original instruction text survives intact. The mapping
  section at the top of the file says which `TypeName` each one uses.
- Implementor, Researcher, and all four `test-*` specialists keep their `hidden: true`
  setting so they do not appear as top-level choices, matching the Kilo behaviour.
- `implementor` and all four `test-*` specialists use a single-purpose `IMPLEMENT`
  report profile; read-only `INVESTIGATE` and `REVIEW` profiles live on `researcher`
  (and `explore` via Delegator's pasted contract).
