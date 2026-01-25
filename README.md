# Antigravity Optimizer

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/nzkbuild/antigravity-optimizer?style=social)](https://github.com/nzkbuild/antigravity-optimizer)
[![GitHub issues](https://img.shields.io/github/issues/nzkbuild/antigravity-optimizer)](https://github.com/nzkbuild/antigravity-optimizer/issues)

**Made for Antigravity IDE**

One-command skill routing for Antigravity workflows and CLI users. It picks the best skills for a task and outputs a ready-to-paste `/skill` prompt.

**Requires the skills library by sickn33:** https://github.com/sickn33/antigravity-awesome-skills

## Why this exists
Most users do not want to memorize 200+ skills. This router makes skills usable for non-technical and "vibe coding" workflows with a single command.

## Features
- One command to select skills and format a `/skill` prompt
- Antigravity `/activate-skills` workflow support
- Skill bundles (frontend/backend/marketing/security/product)
- Easy-mode intake for vague requests
- Auto-copy to clipboard (Windows)
- Verification mode to check skill index health

## Step 0 (required): Install the skills library
```powershell
git clone https://github.com/sickn33/antigravity-awesome-skills.git .agent/skills
```

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

## Credits
- Skills library: https://github.com/sickn33/antigravity-awesome-skills

## License
See `LICENSE`.
