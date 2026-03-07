# Custom Skills

Create your own skills that the Antigravity Optimizer will auto-discover and include in routing.

## Quick Start

1. Create a skill directory:
```bash
mkdir -p .agent/skills/custom/my-team-conventions
```

2. Write your `SKILL.md`:
```markdown
---
name: my-team-conventions
description: Enforce team coding conventions and standards
---

When reviewing or writing code, always:
1. Use TypeScript strict mode
2. Follow our naming conventions (camelCase for functions, PascalCase for components)
3. Include JSDoc comments on all exports
```

3. Verify it's discovered:
```bash
python tools/skill_router.py --search "team"
```

## Structure

```
.agent/skills/custom/
├── my-team-conventions/
│   └── SKILL.md          # Required
├── deployment-process/
│   ├── SKILL.md           # Required
│   ├── checklist.md       # Optional supporting file
│   └── scripts/
│       └── deploy.sh      # Optional script
```

## SKILL.md Format

The minimum required format:
```yaml
---
name: skill-name
description: What this skill does
---
Your instructions here...
```

### Optional Frontmatter Fields

| Field | Purpose |
|---|---|
| `tags` | Keywords for better routing match |
| `disable-model-invocation` | Prevent auto-invocation (user-only) |
| `allowed-tools` | Restrict tool access |
| `context: fork` | Run as subagent |
| `argument-hint` | Placeholder text for invocation |

## Tips

- Keep skill names lowercase with hyphens
- Write clear, specific descriptions for better routing
- Add `tags` for keywords not in the name or description
- Custom skills appear in `--search`, `--info`, and routing alongside built-in skills
