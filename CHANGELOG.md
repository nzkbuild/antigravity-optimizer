# Changelog

All notable changes to the Antigravity Optimizer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-02-03

### Added
- **Skill discovery commands**: `--search`, `--info`, `--list-bundles`
- **Global/Workspace choice**: Choose where to install workflow rules
- **GitHub Actions CI**: Validates JSON and PowerShell syntax on push
- **Issue templates**: Bug report and feature request forms
- **PR template**: Checklist for contributors
- **CI badge**: Shows build status in README

### Changed
- **Consistent prompts**: All prompts now use `[Y/N]` format
- **Better UX**: Clear announcement before modifying global configs
- **Installation choice**: Pick [1] Global, [2] Workspace only, or [3] Skip

## [1.2.0] - 2026-02-03

### Added
- **YAML auto-repair**: Automatically fixes broken skill files on install (both platforms)
- **Python version check**: Router validates Python 3.6+ at startup
- **Bundle validation**: Warns if bundle references non-existent skills
- **Enhanced --verify**: Shows sync status with actionable recommendations

### Changed
- **Skill count display**: Changed from "625+" to "600+" for future-proofing
- **YAML repair loop**: Now handles unlimited nested quotes (was limited to 4)
- **Devops bundle**: Updated to use actual skill IDs from the index

### Fixed
- Linux/macOS missing YAML repair (now has parity with Windows)
- Unicode symbols causing errors on Windows terminals

## [1.1.0] - 2026-02-02

### Added
- **Linux/macOS support**: New `setup.sh` script with full feature parity
- **Silent mode**: `--silent` flag for CI/CD automation
- **Mode parameter**: Skip interactive menu with `--mode essentials|full|update`
- **Version flag**: `--version` shows current version
- **Help system**: `Get-Help .\setup.ps1` and `./setup.sh --help`
- **Prerequisites check**: Validates Git and PowerShell version before running
- **Execution timing**: Shows how long setup took
- **Verbose support**: `-Verbose` flag for debugging

### Changed
- **Transparent global rules**: Now shows exactly what will be added to GEMINI.md
- **Permission prompts**: Asks before modifying global config files
- **Automatic .git removal**: Prevents project Git conflicts for vibe coders
- **Professional logging**: Consistent `[+]` success, `[*]` progress, `[!]` warning format

### Fixed
- Git "address sticker" problem where project Git pointed to optimizer repo

## [1.0.0] - 2026-01-31

### Added
- Initial release
- 600+ skills from sickn33's Antigravity Awesome Skills
- Dual installation: Codex CLI (`~/.codex/skills/`) and Antigravity IDE (`.agent/skills/`)
- Global workflow for `/activate-skills` command
- Custom bundles: frontend, backend, fullstack, marketing, security, product, devops
- Windows PowerShell and bash scripts
