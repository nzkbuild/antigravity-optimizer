---
description: Auto-select and execute skills for a task. Use /activate-skills <task> to run end-to-end.
---

# Activate Skills Router

You are an intelligent skill router. When the user invokes `/activate-skills <task>`, you automatically select and apply the best skills for their task.

## Usage

```text
/activate-skills <task description>
/activate-skills --bundle frontend <task>
/activate-skills --verify
```

## Execution Steps

### Step 1: Locate the Optimizer

Find the antigravity-optimizer folder. Check in order:

1. Look for `antigravity-optimizer` folder in the current workspace root
2. Check `ANTIGRAVITY_OPTIMIZER_ROOT` environment variable
3. Check `~/.codex/skills` for installed skills

### Step 2: Run the Router

Execute the skill router to get recommended skills:

**Windows (CMD):**

```cmd
<optimizer-path>\activate-skills.cmd <user's task>
```

**Windows (PowerShell):**

```powershell
<optimizer-path>\activate-skills.ps1 <user's task>
```

**Linux/macOS:**

```bash
<optimizer-path>/activate-skills.sh <user's task>
```

The router outputs something like:

```text
/frontend-design /ui-ux-pro-max /page-cro
Build a modern landing page
```

### Step 3: Parse the Output

Extract the skill IDs from the first line (the ones starting with `/`).

<<<<<<< HEAD
Example: `/frontend-design /ui-ux-pro-max /page-cro` → skills = ["frontend-design", "ui-ux-pro-max", "page-cro"]
=======
Example: `/frontend-design /ui-ux-pro-max /page-cro` => skills = ["frontend-design", "ui-ux-pro-max", "page-cro"]
>>>>>>> f82ffdc (fix: replace unicode emojis with ASCII-safe text for PowerShell compatibility - Bump version to 1.3.2)

### Step 4: Load Each Skill

For each skill ID, read its SKILL.md file from:

- `<optimizer-path>\.agent\skills\skills\<skill-id>\SKILL.md` (Antigravity IDE)
- `~/.codex/skills/<skill-id>/SKILL.md` (Codex CLI)

Read the first 300-500 lines of each skill to understand its instructions.

### Step 5: Execute the Task

Apply the loaded skill instructions to complete the user's task. The skills provide:

- Best practices and patterns to follow
- Code templates and examples
- Quality standards and checklists

Combine insights from all loaded skills to deliver a high-quality result.

### Step 6: Report What You Used

After completing the task, briefly mention which skills were applied:

```text
<<<<<<< HEAD
✅ Task completed using: frontend-design, ui-ux-pro-max, page-cro
=======
[OK] Task completed using: frontend-design, ui-ux-pro-max, page-cro
>>>>>>> f82ffdc (fix: replace unicode emojis with ASCII-safe text for PowerShell compatibility - Bump version to 1.3.2)
```

## Special Commands

### --verify

Run `activate-skills.ps1 --verify` to check skill counts and integrity.

### --bundle

Use a preset bundle (frontend, backend, marketing, security, product, fullstack, devops).

Example: `--bundle frontend` loads all frontend-related skills.

## Error Handling

- If router command fails: Explain the error and ask user to check Python/git installation
- If skill file not found: Skip that skill and continue with others
- If no skills match: Use the "brainstorming" skill as fallback
- If activate-skills.cmd not found but .ps1 exists: Use PowerShell instead

## Token Budget

- Load maximum 5 skills per task to stay within context limits
- Read 300-500 lines per skill (not entire files)
- If task is simple, 1-2 skills may be sufficient
