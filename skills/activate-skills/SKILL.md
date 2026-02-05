---
name: activate-skills
description: Route a task to Antigravity skills and auto-apply them end-to-end (no copy/paste).
---

# Activate Skills Router (Auto-Execute)

Use this skill when the user invokes `/activate-skills <task>` or `@activate-skills "<task>"`.

Goal: route the task to the best skills and **continue execution automatically** without asking the user to copy/paste the `/skill` line.

## Steps

1) **Locate the optimizer**
   - Prefer `ANTIGRAVITY_OPTIMIZER_ROOT` if set.
   - Otherwise use the current repo root if it contains `activate-skills.ps1`/`activate-skills.cmd`.
   - If not found, ask the user to run `.\setup.ps1` in the optimizer repo.

2) **Run the router**
   - Windows (PowerShell):
     - `<optimizer-root>\activate-skills.ps1 <task>`
   - Windows (CMD):
     - `<optimizer-root>\activate-skills.cmd <task>`
   - Linux/macOS:
     - `<optimizer-root>/activate-skills.sh <task>`

3) **Parse output**
   - First line contains skills: `/skill-a /skill-b ...`
   - Second line is the task text.
   - Extract skill IDs by stripping the leading `/`.

4) **Load skills**
   - Read each `SKILL.md` from:
     - `~/.codex/skills/<skill-id>/SKILL.md` (Codex CLI)
     - or `<optimizer-root>/.agent/skills/skills/<skill-id>/SKILL.md` (Antigravity IDE)
   - Read only what you need (first 300-500 lines).

5) **Apply guardrails**
   - Cap to **3–5** skills.
   - Avoid heavy skills like `loki-mode` unless explicitly requested.
   - Prefer domain-specific skills over generic ones.

6) **Execute the task**
   - Apply the loaded skill instructions to complete the user’s task.
   - If a skill clearly does not fit, skip it and continue.

7) **Report**
   - Mention which skills were used:
     - `[OK] Task completed using: skill-a, skill-b`

## Important

- **Do not** return only the `/skill` line unless the user explicitly asked for routing output only.
- **Do not** ask the user to copy/paste the router output back to you.
- If routing fails, explain the error briefly and suggest running the router command manually.
