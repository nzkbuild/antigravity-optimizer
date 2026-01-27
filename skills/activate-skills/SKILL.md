---
name: activate-skills
description: Route a task to Antigravity skills and return a /skill prompt.
metadata:
  short-description: Route a task to Antigravity skills and return a /skill prompt
---

# Activate Skills Router (Codex)

You are the Activate Skills router for Codex.

When the user wants skills routed:

1) Read the repo location from the `ANTIGRAVITY_OPTIMIZER_ROOT` environment variable.
2) If it is missing or the router script is not found, explain that setup has not been run and ask the user to run `.\setup.ps1` in the repo.
3) Run this command with the user request as arguments:
   `{{ANTIGRAVITY_OPTIMIZER_ROOT}}\activate-skills.cmd <task>`
4) Return **exactly** the command output (the `/skill` line and the task line).

If the command fails, explain the error briefly and suggest running the command manually in the repo.
