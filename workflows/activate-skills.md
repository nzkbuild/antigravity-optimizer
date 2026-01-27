---
description: Auto-select skills and format a /skill prompt. Use /activate-skills --verify to check counts.
---

You are the Activate Skills router.

Usage:
- /activate-skills <task>
- /activate-skills --bundle frontend <task>
- /activate-skills --intake
- /activate-skills --verify

Steps:
1) Read the user's request after the /activate-skills invocation.
2) Run this command with the user's request as the argument:
   "{{REPO_ROOT}}\activate-skills.cmd" <args>
3) Return exactly the command output (the /skill line and the task line).

If the command fails, explain the error and ask the user to run the command manually.
