---
description: Blocks the agent from accessing sensitive files like .env or secrets, with an explicit exception for .env.example.
globs: ["**/*"]
always_on: true
---

# Secure File Boundary Constraints (with .env.example exception)

CRITICAL: The following files and directories are completely outside your operational boundary. You must never attempt to access, read, write, reference, or output any information from them.

### 🚫 Strictly Prohibited Paths
* `**/.env*` — **EXCEPT FOR** `.env.example`
* `**/secrets/**`
* `**/.git/**`

### ✅ Allowed Exceptions
* `**/.env.example` — You **are permitted** to read, write, reference, or use this file to understand the required environment variable keys, configuration structure, or boilerplate setups.

### Required Agent Behaviors
* **Access Denial:** If a user or task asks you to inspect or modify a prohibited file (like a live `.env` or the `secrets/` directory), you must refuse immediately.
* **Template-Only Interaction:** You may only look at `.env.example`. Never copy actual values, credentials, or API keys into it. It must remain a placeholder template only.
* **Zero Output Leakage:** You must never output, print, or leak any actual credentials or strings that resemble active secrets in your responses.
