# Antigravity Optimizer

![Antigravity Banner](assets/banner.svg)

**Stop memorizing skills. Just build.**

[![License: MIT](https://img.shields.io/badge/License-MIT-teal.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/nzkbuild/antigravity-optimizer?style=social)](https://github.com/nzkbuild/antigravity-optimizer)

The **Antigravity Optimizer** automatically picks the right AI skills for your task. 600+ skills, zero memorization.

**Now:** it routes tasks, learns from feedback, and stays out of your way.

> **Credits**: Skills are from **[sickn33's Antigravity Awesome Skills](https://github.com/sickn33/antigravity-awesome-skills)**. We just make them easier to use!

---

## Quick Start

### 1. Setup

```powershell
.\setup.ps1
```

Choose your mode:

- **[1] Essentials** - Installs everything, removes extra docs (recommended)
- **[2] Full Repository** - Keeps all documentation  
- **[3] Update Only** - Quick update (2 seconds)

### 2. Usage

**Windows (CMD):**

```cmd
.\activate-skills.cmd "Build a landing page with dark mode"
```

**Windows (PowerShell):**

```powershell
.\activate-skills.ps1 "Build a landing page with dark mode"
```

**Linux/macOS:**

```bash
./activate-skills.sh "Build a landing page with dark mode"
```

**Inside Antigravity IDE:**

```text
/activate-skills Build a landing page with dark mode
```

**Inside Codex CLI:**

```text
@activate-skills "Build a landing page with dark mode"
```

---

> **For Vibe Coders**: After running the optimizer, just paste the `/skill` output into your chat. The AI will do the rest!

---

## What Gets Installed

| Component | Description |
|-----------|-------------|
| **626 Skills** | Complete AI skills library |
| **Smart Routing** | Picks the best skills for your task |
| **Feedback Memory** | Remembers what worked (`~/.codex/.router_feedback.json`) |
| **Global Workflow** | `/activate-skills` works in any project |
| **Global Rules** | AI knows how to route automatically |
| **Cross-Platform** | Windows, Linux, macOS |
| **Auto-Update** | Run setup anytime to get latest skills |
| **Dual Install** | Works in both Codex CLI and Antigravity IDE |
| **Custom Bundles** | Frontend, backend, marketing presets |

---

## Bundles

Use preset skill bundles:

```powershell
.\activate-skills.ps1 --bundle frontend "Build a pricing page"
.\activate-skills.ps1 --bundle backend "Create a REST API"
.\activate-skills.ps1 --bundle fullstack "Build a SaaS app"
```

Available: `frontend`, `backend`, `fullstack`, `marketing`, `security`, `product`, `devops`

Edit `bundles.json` to customize.

---

## Advanced Usage

```powershell
# Silent install (for CI/CD)
.\setup.ps1 -Mode essentials -Silent

# Update skills only
.\setup.ps1 -Mode update

# Get help
Get-Help .\setup.ps1 -Full

# Debug mode
.\setup.ps1 -Verbose
```

**Feedback storage (safe + local):**

- `~/.codex/.router_feedback.json`

---

## Skill Discovery

```powershell
# Search skills by keyword
python tools/skill_router.py --search react

# View skill details
python tools/skill_router.py --info brainstorming

# List all bundles
python tools/skill_router.py --list-bundles

# Verify installation
python tools/skill_router.py --verify
```

---

## Credits

**Primary Skills Library**: [Antigravity Awesome Skills](https://github.com/sickn33/antigravity-awesome-skills) by **sickn33**. Please star their repo!

## License

MIT (c) [nzkbuild](https://github.com/nzkbuild)
