# Antigravity Optimizer

One-command skill routing for Antigravity workflows and CLI users. It picks the best skills for a task and outputs a ready-to-paste `/skill` prompt.

## Why this exists
Most users do not want to memorize 200+ skills. This router makes skills usable for non-technical and "vibe coding" workflows with a single command.

## Features
- One command to select skills and format a `/skill` prompt
- Antigravity `/activate-skills` workflow support
- Skill bundles (frontend/backend/marketing/security/product)
- Easy-mode intake for vague requests
- Auto-copy to clipboard (Windows)
- Verification mode to check skill index health

## Quick start (CLI)
```powershell
.\activate-skills.ps1 "Build a landing page for a SaaS"
```

Output:
```
/copywriting /page-cro
Build a landing page for a SaaS
```

## Quick start (Antigravity)
1) Install the workflow:
```powershell
.\scripts\install.ps1
```
2) In Antigravity chat:
```
/activate-skills Build a landing page for a SaaS
```

## Common options
```powershell
.\activate-skills.ps1 --bundle frontend "Build a landing page"
.\activate-skills.ps1 --intake
.\activate-skills.ps1 --verify
.\activate-skills.ps1 --no-clipboard "Task text"
```

## Skills source
This project routes to skills from `antigravity-awesome-skills` by sickn33. Install it in `.agent/skills`:
```powershell
git clone https://github.com/sickn33/antigravity-awesome-skills.git .agent/skills
```

## Credits
- Skills library: https://github.com/sickn33/antigravity-awesome-skills

## License
See `LICENSE`.
