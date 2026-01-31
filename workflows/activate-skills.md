---
description: Auto-select and execute skills for a task. Use /activate-skills <task> to run end-to-end.
---

# Activate Skills Router

You are an intelligent skill router. When the user invokes `/activate-skills <task>`, you automatically select and apply the best skills for their task.

## Usage

```
/activate-skills <task description>
/activate-skills --bundle frontend <task>
/activate-skills --verify
```

## Execution Steps

### Step 1: Run the Router

Execute the skill router to get recommended skills:

```powershell
{{REPO_ROOT}}\activate-skills.ps1 <user's task>
```

The router outputs something like:
```
/frontend-design /ui-ux-pro-max /page-cro
Build a modern landing page
```

### Step 2: Parse the Output

Extract the skill IDs from the first line (the ones starting with `/`).

Example: `/frontend-design /ui-ux-pro-max /page-cro` → skills = ["frontend-design", "ui-ux-pro-max", "page-cro"]

### Step 3: Load Each Skill

For each skill ID, read its SKILL.md file:

```
{{REPO_ROOT}}\.agent\skills\skills\<skill-id>\SKILL.md
```

Read the first 300-500 lines of each skill to understand its instructions.

### Step 4: Execute the Task

Apply the loaded skill instructions to complete the user's task. The skills provide:
- Best practices and patterns to follow
- Code templates and examples
- Quality standards and checklists

Combine insights from all loaded skills to deliver a high-quality result.

### Step 5: Report What You Used

After completing the task, briefly mention which skills were applied:

```
✅ Task completed using: frontend-design, ui-ux-pro-max, page-cro
```

## Special Commands

### --verify
Run `{{REPO_ROOT}}\activate-skills.cmd --verify` to check skill counts and integrity.

### --bundle <name>
Use a preset bundle (frontend, backend, marketing, security, product, fullstack, devops).

## Error Handling

- If router command fails: Explain the error and ask user to check Python/git installation
- If skill file not found: Skip that skill and continue with others
- If no skills match: Use the "brainstorming" skill as fallback

## Token Budget

- Load maximum 5 skills per task to stay within context limits
- Read 300-500 lines per skill (not entire files)
- If task is simple, 1-2 skills may be sufficient
