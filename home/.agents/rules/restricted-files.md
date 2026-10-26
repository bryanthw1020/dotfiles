---
description: Blocks access to sensitive files such as .env, secrets, credentials, and keys. Only .env.example is permitted.
globs: ["**/*"]
always_on: true
---

# Secure File Boundary

These paths are outside your operational boundary. Never access, read, write, reference, or output anything from them.

## Prohibited

- `**/.env*`, except `**/.env.example`
- `**/.git/**`, `**/.ssh/**`, `**/secrets/**`
- Firebase: `**/.runtimeconfig.json`, `**/*serviceAccountKey*.json`, `**/*service-account*.json`, `**/*firebase-adminsdk*.json`, `~/.config/configstore/firebase-tools.json`
- Wrangler: `**/.wrangler/state/**`, `**/.wrangler/config/**`, `**/.dev.vars`
- Supabase: `**/supabase/.temp/**`, `**/supabase/.branches/**`, `**/.supabase/**`
- GitHub CLI: `~/.config/gh/**`
- Keys and certificates: `**/*.pem`, `**/*.key`, `**/*.pfx`, `**/*.p12`
- Cloud credentials: `**/.aws/**`, `**/.gcloud/**`, `**/.azure/**`
- Tool authentication: `**/.npmrc`, `**/.pypirc`, `**/.netrc`

## Allowed exceptions

- `**/.env.example`: the only `.env*` file you may open. Read, write, or reference it only as a placeholder template. Never copy real values, credentials, or API keys into it.
- `**/wrangler.toml`, `**/wrangler.json`, `**/wrangler.jsonc`: inspect build and route configuration only, with no hardcoded secrets.
- `**/firebase.json`, `**/.firebaserc`: inspect project targets, routing, and deploy configuration only.
- `**/supabase/config.toml`: inspect service wiring and local ports only.

## Required behavior

- Refuse immediately if asked to inspect or modify a prohibited path.
- Never output, print, or leak real credentials or secret-like strings.
