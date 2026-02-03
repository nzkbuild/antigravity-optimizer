# Changelog

All notable changes to the Antigravity Optimizer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
