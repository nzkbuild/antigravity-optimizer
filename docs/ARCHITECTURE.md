# Antigravity Optimizer Architecture

## Overview

The Antigravity Optimizer routes tasks to the best-matching AI skills from a library of 1,200+ skills.

```
User Task → Tokenize → Score Skills → Pick Top-N → Output → Memory
                ↑                ↑
          Synonyms         Boosts (bundle, profile, feedback, master-memory)
```

## Components

### Core Router (`tools/skill_router.py`)
- **Tokenizer**: Normalizes input, expands synonyms (`auth→authentication`)
- **Scorer**: Weighted overlap scoring (name×3, desc×1, tags×2), normalized by skill token count
- **Picker**: Top-N selection with MIN_SCORE threshold + relative threshold (70% of top score)
- **Fallback**: Category-aware fallback (frontend→frontend-design, database→database-design, etc.)

### Project Profiles (`tools/project_profiles.py`)
Auto-detects project type from marker files (package.json, go.mod, Cargo.toml, etc.) and boosts matching skills. LRU cache at 10 projects max.

### Memory System (`tools/routing_memory.py`)
- **Session Memory**: Per-session routing log at `.agent/session-memory.md` (500-line cap)
- **Routing Diary**: Daily log files at `.agent/routing-diary/YYYY-MM-DD.md`
- **Echo Recall**: `--recall <query>` searches past sessions
- **Master Memory**: `.agent/master-memory.md` for project-level skill preferences

### Custom Skills
Place SKILL.md files in `.agent/skills/custom/<skill-name>/SKILL.md`. Auto-registered on router startup.

## CLI Flags

| Flag | Purpose |
|---|---|
| `--max N` | Max skills to output (default: 3, cap: 5) |
| `--bundle NAME` | Use a preset skill bundle |
| `--feedback SKILL` | Boost a skill for future runs |
| `--why` | Explain scoring (stderr) |
| `--search KEYWORD` | Search skills by keyword |
| `--info SKILL_ID` | Show skill details |
| `--recall QUERY` | Search past routing sessions |
| `--no-clipboard` | Disable clipboard copy |
| `--no-profile` | Disable project profile detection |
| `--no-memory` | Disable session memory and diary |
| `--verify` | Check index vs disk integrity |

## Data Files

| File | Location | Purpose |
|---|---|---|
| `skills_index.json` | Skills root | Main skill index |
| `bundles.json` | Repo root | Preset skill bundles |
| `.router_feedback.json` | `~/.codex/` | Per-skill feedback scores |
| `.project_profiles.json` | `~/.codex/` | LRU project profiles |
| `session-memory.md` | `.agent/` | Current session routing log |
| `routing-diary/` | `.agent/` | Daily routing diary files |
| `master-memory.md` | `.agent/` | Project context preferences |
| `skills_sources.json` | Repo root | Upstream sync config |
