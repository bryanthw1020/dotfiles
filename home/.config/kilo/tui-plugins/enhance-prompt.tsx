/** @jsxImportSource @opentui/solid */
import type { TuiPlugin, TuiPluginApi, TuiPluginModule, TuiPromptInfo, TuiPromptRef } from "@kilocode/plugin/tui"
import { Show, createSignal } from "solid-js"

const PLUGIN_ID = "kilo.enhance-prompt"
const HOME_REF = "::home"
const COMMAND_ENHANCE = "enhance.prompt"
const COMMAND_REVERT = "enhance.revert"

const DEFAULT_KEYBINDS: Record<string, string> = {
  [COMMAND_ENHANCE]: "<leader>p",
  [COMMAND_REVERT]: "<leader>shift+p",
}

// Mirrors the host home-route placeholder list (packages/tui/src/routes/home.tsx).
// The replaced slot must recreate it or the home prompt renders no placeholders.
const HOME_PLACEHOLDERS = {
  normal: ["Fix a TODO in the codebase", "What is the tech stack of this project?", "Fix broken tests"],
  shell: ["ls -la", "git status", "pwd"],
}

type Options = {
  enabled?: boolean
  keybinds?: Record<string, string | false | undefined>
}

type Part = TuiPromptInfo["parts"][number]

function readKeybind(options: Options, name: string, fallback: string): string | undefined {
  const value = options.keybinds?.[name]
  if (value === undefined) return fallback
  if (value === false) return undefined
  if (typeof value !== "string") return fallback
  const trimmed = value.trim()
  if (!trimmed || trimmed === "none") return undefined
  return trimmed
}

function virtualTextOf(part: Part): string {
  if (part.type === "file" && part.source?.text) return part.source.text.value
  if (part.type === "agent" && part.source) return part.source.value
  if (part.type === "text" && part.source?.text) return part.source.text.value
  return ""
}

function reanchor(part: Part, start: number, end: number): Part {
  if (part.type === "file" && part.source?.text) {
    return { ...part, source: { ...part.source, text: { ...part.source.text, start, end } } } as Part
  }
  if (part.type === "agent" && part.source) {
    return { ...part, source: { ...part.source, start, end } } as Part
  }
  if (part.type === "text" && part.source?.text) {
    return { ...part, source: { ...part.source, text: { ...part.source.text, start, end } } } as Part
  }
  return part
}

// Re-anchors mentions/pastes whose virtual token survived the rewrite. Tokens are
// consumed left to right so duplicated tokens cannot collapse onto one offset.
function reanchorParts(parts: TuiPromptInfo["parts"], text: string) {
  let cursor = 0
  let dropped = 0
  const next: TuiPromptInfo["parts"] = []
  for (const part of parts) {
    const token = virtualTextOf(part)
    if (!token) {
      next.push(part)
      continue
    }
    const index = text.indexOf(token, cursor)
    if (index === -1) {
      dropped += 1
      continue
    }
    cursor = index + token.length
    next.push(reanchor(part, index, cursor))
  }
  return { parts: next, dropped }
}

// `ref.current` returns the host's live Solid store object, which is mutated in
// place while the user types. Copy it before awaiting, or the "user kept typing"
// check compares the store against itself and the undo cache holds live state.
function copyPrompt(info: TuiPromptInfo): TuiPromptInfo {
  return { input: info.input, parts: JSON.parse(JSON.stringify(info.parts)) as TuiPromptInfo["parts"] }
}

function sessionDirectory(api: TuiPluginApi, sessionID: string): string | undefined {
  try {
    const session = (api.state as unknown as { session?: { get?: (id: string) => { directory?: string } | undefined } })
      .session
    if (typeof session?.get !== "function") return undefined
    return session.get(sessionID)?.directory
  } catch {
    return undefined
  }
}

const tui: TuiPlugin = async (api, options) => {
  const opts = (options ?? {}) as Options
  if (opts.enabled === false) return

  const toast = api.ui.toast
  const refs = new Map<string, TuiPromptRef>()
  const undo = new Map<string, TuiPromptInfo>()
  // Ref key of the prompt currently being enhanced, or undefined; drives the
  // in-prompt status indicator and the single-flight guard.
  const [runningKey, setRunningKey] = createSignal<string | undefined>(undefined)

  const canSlots = typeof api.slots?.register === "function" && typeof api.ui?.Prompt === "function"
  const canKeymap = typeof api.keymap?.registerLayer === "function"
  if (!canSlots || !canKeymap) {
    toast({ variant: "error", title: "Enhance prompt", message: "This Kilo version lacks the prompt plugin API" })
    return
  }

  const setRef = (key: string, ref: TuiPromptRef | undefined) => {
    if (ref) refs.set(key, ref)
    else refs.delete(key)
  }

  const currentTarget = (): { key: string; ref: TuiPromptRef } | undefined => {
    const route = api.route.current as { name: string; params?: { sessionID?: string } }
    if (route.name === "home") {
      const ref = refs.get(HOME_REF)
      if (ref) return { key: HOME_REF, ref }
    } else if (route.name === "session" && route.params?.sessionID) {
      const ref = refs.get(route.params.sessionID)
      if (ref) return { key: route.params.sessionID, ref }
    }
    for (const [key, ref] of refs) if (ref.focused) return { key, ref }
    return undefined
  }

  const enhance = async () => {
    if (runningKey()) {
      toast({ variant: "info", title: "Enhance prompt", message: "Already enhancing" })
      return
    }
    const target = currentTarget()
    if (!target) {
      toast({ variant: "warning", title: "Enhance prompt", message: "No active prompt" })
      return
    }
    const { key, ref } = target
    const before = copyPrompt(ref.current)
    // The host does not expose the prompt's normal/shell mode through the ref, so a
    // shell-mode draft cannot be detected here; one-step undo covers a mistaken enhance.
    if (!before.input.trim()) {
      toast({ variant: "info", title: "Enhance prompt", message: "Nothing to enhance" })
      return
    }
    const endpoint = (api.client as unknown as { enhancePrompt?: { enhance?: (...args: unknown[]) => unknown } })
      .enhancePrompt
    if (typeof endpoint?.enhance !== "function") {
      toast({ variant: "error", title: "Enhance prompt", message: "Prompt enhance is unavailable" })
      return
    }

    const directory = key === HOME_REF ? undefined : sessionDirectory(api, key)
    setRunningKey(key)
    toast({ variant: "info", title: "Enhance prompt", message: "Enhancing...", duration: 4000 })
    try {
      const result = (await (endpoint.enhance as (...args: unknown[]) => Promise<unknown>)(
        { text: before.input, directory },
        { throwOnError: true },
      )) as { data?: { text?: string }; text?: string } | undefined
      // The SDK returns the hey-api envelope ({ data }) even with throwOnError;
      // accept an unwrapped shape too in case that changes.
      const payload = (result?.data ?? result) as { text?: string } | undefined
      const text = typeof payload?.text === "string" ? payload.text : ""

      if (ref.current.input !== before.input) {
        toast({ variant: "info", title: "Enhance prompt", message: "Prompt changed while enhancing; discarded" })
        return
      }
      if (!text || text === before.input) {
        toast({ variant: "info", title: "Enhance prompt", message: "Prompt is already clear" })
        return
      }

      const { parts, dropped } = reanchorParts(before.parts, text)
      undo.set(key, before)
      ref.set({ input: text, parts })
      const note = dropped > 0 ? ` (${dropped} mention${dropped === 1 ? "" : "s"} removed)` : ""
      toast({ variant: "success", title: "Enhance prompt", message: `Prompt enhanced${note}` })
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error)
      toast({
        variant: "error",
        title: "Enhance prompt",
        message: message.slice(0, 200) || "Enhance failed",
      })
    } finally {
      setRunningKey(undefined)
    }
  }

  const revert = () => {
    const target = currentTarget()
    if (!target) {
      toast({ variant: "warning", title: "Enhance prompt", message: "No active prompt" })
      return
    }
    const cached = undo.get(target.key)
    if (!cached) {
      toast({ variant: "info", title: "Enhance prompt", message: "Nothing to revert" })
      return
    }
    undo.delete(target.key)
    target.ref.set(cached)
    toast({ variant: "success", title: "Enhance prompt", message: "Reverted to the previous draft" })
  }

  const bindings: { key: string; cmd: string; desc: string }[] = []
  const enhanceKey = readKeybind(opts, COMMAND_ENHANCE, DEFAULT_KEYBINDS[COMMAND_ENHANCE]!)
  if (enhanceKey) bindings.push({ key: enhanceKey, cmd: COMMAND_ENHANCE, desc: "Enhance the prompt draft" })
  const revertKey = readKeybind(opts, COMMAND_REVERT, DEFAULT_KEYBINDS[COMMAND_REVERT]!)
  if (revertKey) bindings.push({ key: revertKey, cmd: COMMAND_REVERT, desc: "Revert the enhanced prompt" })

  // Commands go on an ungated layer: the palette and slash autocomplete enumerate
  // only "reachable" commands, and a mode-gated layer is unreachable while the
  // palette/autocomplete mode is active (the host's legacy command shim also
  // registers without a mode). Bindings stay base-gated so the keys do not fire
  // while a dialog or autocomplete is open.
  api.keymap.registerLayer({
    commands: [
      {
        name: COMMAND_ENHANCE,
        title: "Enhance prompt",
        desc: "Rewrite the current prompt draft with the enhance model",
        category: "Prompt",
        namespace: "palette",
        slashName: "enhance",
        run() {
          void enhance()
        },
      },
      {
        name: COMMAND_REVERT,
        title: "Revert enhanced prompt",
        desc: "Restore the draft from before the last enhance",
        category: "Prompt",
        namespace: "palette",
        run() {
          revert()
        },
      },
    ],
  })

  api.keymap.registerLayer({
    mode: "base",
    bindings,
  })

  // Replaces the host prompt so the live draft is reachable through the slot ref.
  // Every host prop, including ref, must be forwarded or host features
  // (session.undo, timeline/message "prompt" actions, --prompt seeding) break.
  api.slots.register({
    order: 100,
    slots: {
      session_prompt(_ctx, props) {
        if (props.visible === false) return null
        return (
          <api.ui.Prompt
            sessionID={props.session_id}
            visible={props.visible}
            disabled={props.disabled}
            onSubmit={props.on_submit}
            directory={sessionDirectory(api, props.session_id)}
            ref={(r) => {
              setRef(props.session_id, r)
              props.ref?.(r)
            }}
            right={<api.ui.Slot name="session_prompt_right" session_id={props.session_id} />}
          />
        )
      },
      home_prompt(_ctx, props) {
        return (
          <api.ui.Prompt
            ref={(r) => {
              setRef(HOME_REF, r)
              props.ref?.(r)
            }}
            right={<api.ui.Slot name="home_prompt_right" />}
            placeholders={HOME_PLACEHOLDERS}
          />
        )
      },
      // In-prompt status so the run is visible while the request is in flight.
      session_prompt_right(_ctx, props) {
        return (
          <Show when={runningKey() === props.session_id}>
            <text fg={api.theme?.current?.info}>Enhancing prompt...</text>
          </Show>
        )
      },
      home_prompt_right() {
        return (
          <Show when={runningKey() === HOME_REF}>
            <text fg={api.theme?.current?.info}>Enhancing prompt...</text>
          </Show>
        )
      },
    },
  })

  api.lifecycle?.onDispose?.(() => {
    refs.clear()
    undo.clear()
  })
}

const plugin: TuiPluginModule & { id: string } = {
  id: PLUGIN_ID,
  tui,
}

export default plugin
