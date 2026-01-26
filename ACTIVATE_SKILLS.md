# Activate Skills Router

One command to pick the best skills and format an Antigravity prompt.

Usage:

```powershell
.\scripts\install.ps1 -AddPath
.\activate-skills.ps1 "Design a pricing page for a SaaS"
```

or:

```powershell
activate-skills "Design a pricing page for a SaaS"
```

Output:

```
/copywriting /page-cro
Design a pricing page for a SaaS
```

Auto-copy:
The output is copied to your clipboard by default, so you can paste into Antigravity.
Use `--no-clipboard` to disable.

Optional feedback (boosts skills for future routing):

```powershell
.\activate-skills.ps1 "Build a Discord bot" --feedback discord-bot-architect
```

Use a bundle:

```powershell
.\activate-skills.ps1 --bundle frontend "Build a landing page"
```

Easy-mode intake:

```powershell
.\activate-skills.ps1 --intake
```

Verify skills index vs folders:

```powershell
.\activate-skills.ps1 --verify
```
