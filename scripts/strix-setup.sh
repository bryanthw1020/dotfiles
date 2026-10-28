#!/usr/bin/env bash
# Create ~/.strix/cli-config.json without putting the API key in shell
# history, argv, or git. Re-run to rotate the key.
#
# Usage:
#   bash scripts/strix-setup.sh kilo       # Kilo Gateway (default)
#   bash scripts/strix-setup.sh opencode   # OpenCode Go
#
# strix reads this file as its settings store and rewrites it (mode 0600) after
# a successful run, so this path must stay local and must not be linked from
# home.nix.
#
# OpenCode Go requires an x-opencode-session header plus a non-generic
# User-Agent. Strix applies LLM_EXTRA_HEADERS to every LLM request, so the
# OpenCode preset generates one stable session id and stores it here. Use the
# strix-go wrapper instead of plain strix to mint a fresh id per scan.
set -euo pipefail

provider="${1:-kilo}"

case "$provider" in
  kilo)
    model="openai/deepseek/deepseek-v4.1-flash"
    api_base="https://ai-gateway.kilo.ai/api/v1"
    key_hint="Kilo Gateway API key"
    session_id=""
    ;;
  opencode|opencode-go)
    model="openai/deepseek-v4.1-flash"
    api_base="https://opencode.ai/inference/go/openai/v1"
    key_hint="OpenCode Go API key"
    if command -v openssl >/dev/null 2>&1; then
      session_id="ses_$(openssl rand -hex 16)"
    else
      session_id="ses_$(uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]')"
    fi
    ;;
  -h|--help)
    echo "usage: $0 [kilo|opencode]" >&2
    exit 0
    ;;
  *)
    echo "usage: $0 [kilo|opencode]" >&2
    exit 2
    ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found. Run ./rebuild.sh first (installs jq)." >&2
  exit 1
fi

config_dir="$HOME/.strix"
config_file="$config_dir/cli-config.json"

if [ -f "$config_file" ]; then
  echo "Replacing existing $config_file." >&2
fi

printf '%s: ' "$key_hint" >&2
IFS= read -rs api_key
printf '\n' >&2
if [ -z "$api_key" ]; then
  echo "empty key; nothing written" >&2
  exit 1
fi

umask 077
mkdir -p "$config_dir"
chmod 700 "$config_dir"
tmp="$(mktemp "$config_dir/.cli-config.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

# Pass the key through jq's environment, not its argv, so it never appears in
# `ps` output while the file is written.
STRIX_API_KEY="$api_key" jq -n \
  --arg model "$model" \
  --arg base "$api_base" \
  --arg session "$session_id" \
  --arg ua "strix/1.7.0" \
  '{
    env: ({
      STRIX_LLM: $model,
      LLM_API_BASE: $base,
      LLM_API_KEY: env.STRIX_API_KEY,
      STRIX_API_TYPE: "chat_completions"
    } + (if $session == "" then {} else {
      LLM_EXTRA_HEADERS: {
        "x-opencode-session": $session,
        "User-Agent": $ua
      }
    } end))
  }' >"$tmp"

chmod 600 "$tmp"
mv "$tmp" "$config_file"
trap - EXIT
unset api_key

printf 'Wrote %s (0600).\n' "$config_file"
jq -r '.env | "model: \(.STRIX_LLM)\nbase:  \(.LLM_API_BASE)\ntype:  \(.STRIX_API_TYPE)"' "$config_file"
if [ -n "$session_id" ]; then
  printf 'session: %s\n' "$session_id"
fi
