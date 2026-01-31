# Contributing

Thanks for your interest in improving Antigravity Optimizer!

## Code of Conduct

Be respectful, inclusive, and constructive. We welcome contributors of all backgrounds.

## How to Contribute

1. Fork the repo and create a branch
2. Make changes with clear commit messages
3. Open a pull request with a short description and screenshots/logs when relevant

## Project Structure

| File/Folder | Purpose |
|-------------|---------|
| `setup.ps1` | Main entry point for users |
| `tools/skill_router.py` | Core routing logic |
| `scripts/install.ps1` | Installation and update logic |
| `workflows/activate-skills.md` | Antigravity workflow definition |
| `bundles.json` | Configurable skill bundles |
| `activate-skills.ps1/.sh` | CLI wrappers |

## Development

To test changes locally:
```powershell
python tools\skill_router.py "test task" --verify
```

## Reporting Issues

Please include:
- What you expected vs what happened
- Exact command you ran
- OS/version

## Credits

Please keep attribution to the original skills library: https://github.com/sickn33/antigravity-awesome-skills
