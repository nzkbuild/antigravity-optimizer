"""Session Memory and Routing Diary for the Antigravity Optimizer.

Implements AI-MemoryCore-inspired features:
- Session memory: per-session routing log (capped at 500 lines)
- Routing diary: daily log files with monthly archiving
- Echo recall: search past routing sessions by keyword
- Master memory: project context file for skill boosting
"""
import json
import os
import re
from datetime import datetime
from pathlib import Path

MAX_SESSION_LINES = 500
MEMORY_DIR_NAME = ".agent"
DIARY_DIR_NAME = "routing-diary"


def get_memory_root():
    """Return the memory root directory (CWD/.agent/)."""
    return Path.cwd() / MEMORY_DIR_NAME


def get_session_memory_path():
    return get_memory_root() / "session-memory.md"


def get_diary_dir():
    return get_memory_root() / DIARY_DIR_NAME


def get_master_memory_path():
    return get_memory_root() / "master-memory.md"


# ============================================================================
# Session Memory (3.1)
# ============================================================================

def write_session_entry(task, picked, bundle_name, scores=None):
    """Append a routing session to session-memory.md."""
    path = get_session_memory_path()
    path.parent.mkdir(parents=True, exist_ok=True)

    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    skills_str = ", ".join(picked) if picked else "none"
    bundle_str = bundle_name or "none"

    entry_lines = [
        f"\n## Session: {now}\n",
        f"- **Task:** {task}\n",
        f"- **Skills:** {skills_str}\n",
        f"- **Bundle:** {bundle_str}\n",
    ]
    if scores:
        score_parts = [f"{name}({score:.1f})" for name, score in scores[:5]]
        entry_lines.append(f"- **Scores:** {', '.join(score_parts)}\n")
    entry_lines.append("\n")

    # Append entry
    existing = ""
    if path.exists():
        existing = path.read_text(encoding="utf-8")

    new_content = existing + "".join(entry_lines)

    # Rotate if over limit
    lines = new_content.splitlines(keepends=True)
    if len(lines) > MAX_SESSION_LINES:
        # Archive overflow to diary
        overflow = lines[:len(lines) - MAX_SESSION_LINES]
        _archive_to_diary(overflow)
        new_content = "".join(lines[len(lines) - MAX_SESSION_LINES:])

    path.write_text(new_content, encoding="utf-8")


# ============================================================================
# Routing Diary (3.2)
# ============================================================================

def _archive_to_diary(overflow_lines):
    """Archive overflow session lines to daily diary file."""
    diary_dir = get_diary_dir()
    diary_dir.mkdir(parents=True, exist_ok=True)
    today = datetime.now().strftime("%Y-%m-%d")
    diary_file = diary_dir / f"{today}.md"

    header = ""
    if not diary_file.exists():
        header = f"# Routing Diary — {today}\n\n"

    with diary_file.open("a", encoding="utf-8") as f:
        if header:
            f.write(header)
        f.writelines(overflow_lines)


def write_diary_entry(task, picked, bundle_name, scores=None):
    """Write a routing entry directly to today's diary file."""
    diary_dir = get_diary_dir()
    diary_dir.mkdir(parents=True, exist_ok=True)

    today = datetime.now().strftime("%Y-%m-%d")
    now = datetime.now().strftime("%H:%M:%S")
    diary_file = diary_dir / f"{today}.md"

    header = ""
    if not diary_file.exists():
        header = f"# Routing Diary — {today}\n\n"

    skills_str = ", ".join(picked) if picked else "none"
    entry = (
        f"### {now}\n"
        f"- Task: {task}\n"
        f"- Skills: {skills_str}\n"
        f"- Bundle: {bundle_name or 'none'}\n"
    )
    if scores:
        score_parts = [f"{n}({s:.1f})" for n, s in scores[:5]]
        entry += f"- Scores: {', '.join(score_parts)}\n"
    entry += "\n"

    with diary_file.open("a", encoding="utf-8") as f:
        if header:
            f.write(header)
        f.write(entry)


def archive_old_diaries():
    """Move diary files older than current month to archive/YYYY-MM/ folder."""
    diary_dir = get_diary_dir()
    if not diary_dir.exists():
        return

    current_month = datetime.now().strftime("%Y-%m")
    archive_base = diary_dir / "archive"

    for diary_file in diary_dir.glob("*.md"):
        # Extract date from filename (YYYY-MM-DD.md)
        name = diary_file.stem
        if len(name) == 10 and name[:7] != current_month:
            month_dir = archive_base / name[:7]
            month_dir.mkdir(parents=True, exist_ok=True)
            diary_file.rename(month_dir / diary_file.name)


# ============================================================================
# Echo Recall (3.3)
# ============================================================================

def recall(query, max_results=10):
    """Search routing diary for past sessions matching query keywords."""
    diary_dir = get_diary_dir()
    results = []
    query_tokens = set(query.lower().split())

    # Search diary files (newest first)
    search_dirs = [diary_dir]
    archive_dir = diary_dir / "archive"
    if archive_dir.exists():
        for month_dir in sorted(archive_dir.iterdir(), reverse=True):
            if month_dir.is_dir():
                search_dirs.append(month_dir)

    for search_dir in search_dirs:
        if not search_dir.exists():
            continue
        for diary_file in sorted(search_dir.glob("*.md"), reverse=True):
            if len(results) >= max_results:
                break
            try:
                content = diary_file.read_text(encoding="utf-8")
                # Parse entries
                entries = re.split(r"^### ", content, flags=re.MULTILINE)
                for entry in entries:
                    if not entry.strip():
                        continue
                    entry_lower = entry.lower()
                    if any(t in entry_lower for t in query_tokens):
                        # Extract task line
                        task_match = re.search(r"Task:\s*(.+)", entry)
                        skills_match = re.search(r"Skills:\s*(.+)", entry)
                        time_match = re.match(r"(\d{2}:\d{2})", entry)
                        if task_match:
                            results.append({
                                "date": diary_file.stem,
                                "time": time_match.group(1) if time_match else "??:??",
                                "task": task_match.group(1).strip(),
                                "skills": skills_match.group(1).strip() if skills_match else "unknown",
                            })
                    if len(results) >= max_results:
                        break
            except Exception:
                continue

    # Also search session memory
    session_path = get_session_memory_path()
    if session_path.exists() and len(results) < max_results:
        try:
            content = session_path.read_text(encoding="utf-8")
            entries = re.split(r"^## Session:", content, flags=re.MULTILINE)
            for entry in entries:
                if not entry.strip():
                    continue
                entry_lower = entry.lower()
                if any(t in entry_lower for t in query_tokens):
                    task_match = re.search(r"\*\*Task:\*\*\s*(.+)", entry)
                    skills_match = re.search(r"\*\*Skills:\*\*\s*(.+)", entry)
                    date_match = re.match(r"\s*(\d{4}-\d{2}-\d{2})", entry)
                    if task_match:
                        results.append({
                            "date": date_match.group(1) if date_match else "today",
                            "time": "",
                            "task": task_match.group(1).strip(),
                            "skills": skills_match.group(1).strip() if skills_match else "unknown",
                        })
                if len(results) >= max_results:
                    break
        except Exception:
            pass

    return results


# ============================================================================
# Master Memory (3.4)
# ============================================================================

def load_master_memory():
    """Load master-memory.md and extract preferences."""
    path = get_master_memory_path()
    if not path.exists():
        return {"preferred": set(), "avoid": set(), "notes": []}

    try:
        content = path.read_text(encoding="utf-8")
    except Exception:
        return {"preferred": set(), "avoid": set(), "notes": []}

    preferred = set()
    avoid = set()
    notes = []

    for line in content.splitlines():
        line = line.strip()
        if line.startswith("- **Preferred Skills:**"):
            skills_str = line.split(":", 1)[1].strip()
            preferred = {s.strip() for s in skills_str.split(",") if s.strip()}
        elif line.startswith("- **Avoid Skills:**"):
            skills_str = line.split(":", 1)[1].strip()
            avoid = {s.strip() for s in skills_str.split(",") if s.strip()}
        elif line.startswith("- **Notes:**"):
            notes.append(line.split(":", 1)[1].strip())

    return {"preferred": preferred, "avoid": avoid, "notes": notes}


def get_master_memory_boosts():
    """Return (boost_set, penalty_set) from master memory."""
    mem = load_master_memory()
    return mem["preferred"], mem["avoid"]
