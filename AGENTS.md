# Repository Guidelines

## Project Structure & Module Organization

- `tools/` contains the core Python router (`tools/skill_router.py`).
- `scripts/` holds PowerShell automation like installer/update logic (`scripts/install.ps1`).
- `workflows/` documents Antigravity workflows (e.g., `workflows/activate-skills.md`).
- Root scripts (`setup.ps1`, `activate-skills.ps1`, `activate-skills.sh`) are the user entry points.
- `assets/` stores static assets (e.g., `assets/banner.svg`).

## Build, Test, and Development Commands

- `.\setup.ps1` installs or updates skills and tooling (see `README.md` for modes).
- `.\activate-skills.ps1 "Your task"` runs the skill router via PowerShell.
- `python tools\skill_router.py "test task" --verify` verifies routing and installation.

No formal build step exists; the repository is script-driven.

## Coding Style & Naming Conventions

- PowerShell scripts use `PascalCase` function names and clear parameter blocks.
- Python follows standard PEP 8 conventions; prefer descriptive, lower_snake_case names.
- Keep scripts defensive and readable; avoid clever one-liners unless they improve clarity.

## Testing Guidelines

- There is no dedicated test suite. Validation is done via `tools/skill_router.py --verify`.
- When changing routing logic, verify with realistic prompts and at least one bundle use case.

## Commit & Pull Request Guidelines

- Commit messages follow Conventional Commits (`feat:`, `fix:`, `refactor:`).
- PRs should include:
  - A brief summary of behavior changes.
  - Any new commands or flags introduced.
  - Screenshots or logs if user-facing output changed.

## Security & Configuration Tips

- Do not commit secrets. Local feedback lives in `~/.codex/.router_feedback.json` and must stay local.
- Preserve attribution to the original skills library in documentation updates.
