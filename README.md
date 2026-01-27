# Antigravity Optimizer

![Antigravity Banner](assets/banner.svg)

Stop memorizing skills. Just build.

The Antigravity Optimizer routes your request to the best skills and outputs a ready-to-use /skill prompt.

Note: This project is a router and workflow helper. The underlying skills are authored by [sickn33].

## Quick Start

Run setup after cloning:

```powershell
.\setup.ps1
```

Setup installs skills into your Codex skills folder, sets up the Antigravity workflow, and installs the `activate-skills` Codex skill. Restart Codex after setup to pick up the new skill.

## Where Things Go

By default, everything is auto-detected. You do not need to provide a path.

- **Codex skills folder**: `%CODEX_HOME%\skills` if `CODEX_HOME` is set, otherwise `C:\Users\<you>\.codex\skills`
- **Antigravity workflow**: `C:\Users\<you>\.gemini\antigravity\global_workflows\activate-skills.md`
- **Router location**: this repo (saved in `ANTIGRAVITY_OPTIMIZER_ROOT`)

If you need a custom skills location, set `ANTIGRAVITY_SKILLS_ROOT` before running `.\setup.ps1`. This should still point to Codex's skills folder if you want Codex to load them.

## Usage

From your terminal:

```powershell
.\activate-skills.ps1 "Make a modern landing page"
```

Inside Antigravity IDE:

```
/activate-skills Make a modern landing page
```

Inside Codex (no terminal):
Use the `activate-skills` skill and provide your task. It runs the router and returns the /skill prompt.

## How It Works (3 Steps)

1) Run `.\setup.ps1`
   - Downloads the skills repo into a local cache
   - Copies all skills into Codex's skills folder
   - Installs Antigravity workflow and the Codex `activate-skills` skill
2) Invoke the router
   - Antigravity: `/activate-skills <task>`
   - Codex: use the `activate-skills` skill
3) Apply the output
   - The router returns `/skill ...` + task; paste/send it to apply the skills

## Troubleshooting

- **Codex doesn't see `activate-skills`**
  - Restart Codex after running `.\setup.ps1`.
  - Check that `activate-skills` exists under `C:\Users\<you>\.codex\skills` (or `%CODEX_HOME%\skills`).

- **Router says `skills_index.json` not found**
  - Run `.\scripts\install.ps1` again.
  - If you set `ANTIGRAVITY_SKILLS_ROOT`, ensure it points to the folder that contains `skills_index.json`.

- **Setup fails to clone skills**
  - Install git, then rerun `.\setup.ps1`.
  - If you're behind a proxy or offline, cloning will fail.

- **Antigravity `/activate-skills` doesn't work**
  - Re-run `.\scripts\install.ps1` to reinstall the workflow.
  - Ensure this repo still exists at the same path (the workflow calls the router here).

## Credits

Primary Skills Library: Antigravity Awesome Skills by [sickn33].

## License

MIT (c) [nzkbuild]
