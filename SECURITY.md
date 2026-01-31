# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please follow these steps:

### How to Report

1. **Do NOT open a public issue** - Security vulnerabilities should be reported privately.

2. **Email**: Send details to **security@nzkbuild.dev** (or open a private security advisory on GitHub)

3. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Any suggested fixes (optional)

### What to Expect

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 7 days
- **Resolution Timeline**: Depends on severity
  - Critical: 24-72 hours
  - High: 1-2 weeks
  - Medium/Low: Next release cycle

### Scope

This security policy covers:
- The skill router (`tools/skill_router.py`)
- Installation scripts (`setup.ps1`, `scripts/install.ps1`)
- CLI wrappers (`activate-skills.ps1`, `.cmd`, `.sh`)

### Out of Scope

- Vulnerabilities in the underlying skills library (report to [sickn33/antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills))
- Issues in Python itself
- User misconfiguration

## Security Best Practices

When using the Antigravity Optimizer:
- Always review installed skills before using them
- Don't run `setup.ps1` with elevated privileges unless necessary
- Keep Python updated to the latest stable version
