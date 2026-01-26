#!/usr/bin/env python
import argparse
import json
import re
import sys
from pathlib import Path
import os
import subprocess


DEFAULT_MAX_SKILLS = 2
MAX_SKILLS_CAP = 3
MIN_SCORE = 2
RELATIVE_THRESHOLD = 0.7
REPO_ROOT = Path(__file__).resolve().parents[1]
SKILLS_ROOT = REPO_ROOT / ".agent" / "skills"
FEEDBACK_FILE = SKILLS_ROOT / ".router_feedback.json"
BUNDLES = {
    "frontend": ["frontend-design", "ui-ux-pro-max", "react-best-practices"],
    "backend": ["backend-dev-guidelines", "api-patterns", "database-design"],
    "marketing": ["copywriting", "page-cro", "seo-audit"],
    "security": ["vulnerability-scanner", "security-review", "api-security-best-practices"],
    "product": ["ai-product", "product-requirements", "brainstorming"],
}


def normalize(text):
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return text.strip()


def tokenize(text):
    return [t for t in normalize(text).split() if t]


def load_index(index_path):
    with index_path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if isinstance(data, dict) and "skills" in data:
        return data["skills"]
    if isinstance(data, list):
        return data
    return []


def load_feedback():
    if not FEEDBACK_FILE.exists():
        return {}
    try:
        with FEEDBACK_FILE.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        if isinstance(data, dict):
            return data
    except Exception:
        pass
    return {}


def save_feedback(feedback):
    FEEDBACK_FILE.parent.mkdir(parents=True, exist_ok=True)
    with FEEDBACK_FILE.open("w", encoding="utf-8") as handle:
        json.dump(feedback, handle, indent=2, sort_keys=True)


def score_skill(skill, task_tokens, feedback, bundle_set):
    name = skill.get("id") or skill.get("name") or ""
    description = skill.get("description") or ""
    path = skill.get("path") or ""
    name_tokens = set(tokenize(name))
    desc_tokens = set(tokenize(description))
    path_tokens = set(tokenize(path))

    score = 0
    for token in task_tokens:
        if token in name_tokens or token in path_tokens:
            score += 3
        if token in desc_tokens:
            score += 1

    if name in bundle_set:
        score += 5

    boost = feedback.get(name)
    if isinstance(boost, (int, float)):
        score += boost
    return score, name


def pick_skills(skills, task, max_skills, feedback, bundle_set):
    task_tokens = tokenize(task)
    scored = []
    for skill in skills:
        score, name = score_skill(skill, task_tokens, feedback, bundle_set)
        scored.append((score, name))

    scored.sort(key=lambda item: item[0], reverse=True)
    top_score = scored[0][0] if scored else 0

    picked = []
    for score, name in scored:
        if len(picked) >= max_skills:
            break
        if score <= 0:
            continue
        if score >= max(MIN_SCORE, int(top_score * RELATIVE_THRESHOLD)):
            picked.append(name)

    if not picked:
        fallback = next((s.get("id") for s in skills if s.get("id") == "brainstorming"), None)
        if fallback:
            picked = [fallback]
        else:
            picked = [scored[0][1]] if scored else []

    return picked


def normalize_choice(value, options, default):
    value = (value or "").strip().lower()
    if not value:
        return default
    if value in options:
        return options[value]
    return default


def run_intake(initial_task):
    print("Quick intake (press Enter to accept defaults).", file=sys.stderr)
    task = initial_task.strip()
    if not task:
        task = input("What do you want to build or improve? ").strip()

    area = normalize_choice(
        input("Which area? [A] Design [B] Copy/Marketing [C] Engineering [D] Not sure: "),
        {"a": "design", "b": "copy/marketing", "c": "engineering", "d": "unsure"},
        "unsure",
    )
    platform = normalize_choice(
        input("Where will it run? [A] Web [B] Mobile [C] Backend [D] Not sure: "),
        {"a": "web", "b": "mobile", "c": "backend", "d": "unsure"},
        "unsure",
    )
    stack = normalize_choice(
        input("Tech stack? [A] React/Next [B] Vue/Nuxt [C] Svelte [D] Not sure: "),
        {"a": "react/next", "b": "vue/nuxt", "c": "svelte", "d": "unsure"},
        "unsure",
    )

    brief_parts = [f"Task: {task}"]
    brief_parts.append(f"Area: {area}")
    brief_parts.append(f"Platform: {platform}")
    brief_parts.append(f"Stack: {stack}")
    return " | ".join(brief_parts)


def copy_to_clipboard(text):
    if os.name != "nt":
        return False
    try:
        proc = subprocess.run(
            ["powershell", "-NoProfile", "-Command", "Set-Clipboard -Value ([Console]::In.ReadToEnd())"],
            input=text,
            text=True,
            capture_output=True,
        )
        return proc.returncode == 0
    except Exception:
        return False


def parse_args():
    parser = argparse.ArgumentParser(
        description="Route a task to the best Antigravity skills and emit /skill prompt."
    )
    parser.add_argument("task", nargs="*", help="Task text to route")
    parser.add_argument("--max", type=int, default=DEFAULT_MAX_SKILLS, help="Max skills to emit")
    parser.add_argument(
        "--feedback",
        nargs="+",
        help="Skills that were correct; boosts them for future runs",
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="Verify skills_index.json against SKILL.md folders and print counts",
    )
    parser.add_argument(
        "--bundle",
        choices=sorted(BUNDLES.keys()),
        help="Use a preset skill bundle (frontend/backend/marketing/etc.)",
    )
    parser.add_argument(
        "--intake",
        action="store_true",
        help="Run a quick intake to turn vague requests into a clear brief",
    )
    parser.add_argument(
        "--no-clipboard",
        action="store_true",
        help="Disable auto-copy to clipboard",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    max_skills = max(1, min(args.max, MAX_SKILLS_CAP))
    task = " ".join(args.task).strip()

    index_path = SKILLS_ROOT / "skills_index.json"
    if not index_path.exists():
        print("Error: skills_index.json not found at .agent/skills/skills_index.json", file=sys.stderr)
        return 1

    skills = load_index(index_path)
    if args.verify:
        skills_dir = SKILLS_ROOT / "skills"
        skill_paths = {str(p.parent.relative_to(SKILLS_ROOT).as_posix()) for p in skills_dir.rglob("SKILL.md")}
        index_paths = {item.get("path") for item in skills if isinstance(item, dict) and item.get("path")}
        missing_on_disk = sorted(index_paths - skill_paths)
        missing_in_index = sorted(skill_paths - index_paths)
        print(f"skills_index.json entries: {len(index_paths)}")
        print(f"SKILL.md folders: {len(skill_paths)}")
        print(f"Missing on disk: {len(missing_on_disk)}")
        print(f"Missing in index: {len(missing_in_index)}")
        if missing_on_disk:
            print("Missing on disk (sample 20):")
            print("\n".join(missing_on_disk[:20]))
        if missing_in_index:
            print("Missing in index (sample 20):")
            print("\n".join(missing_in_index[:20]))
        return 0

    if not task:
        print("Error: task text is required.", file=sys.stderr)
        return 1

    if args.intake:
        task = run_intake(task)

    feedback = load_feedback()
    bundle_set = set(BUNDLES.get(args.bundle or "", []))
    picked = pick_skills(skills, task, max_skills, feedback, bundle_set)

    if args.feedback:
        for name in args.feedback:
            feedback[name] = feedback.get(name, 0) + 2
        save_feedback(feedback)

    output_lines = []
    if picked:
        output_lines.append(" ".join(f"/{name}" for name in picked))
    output_lines.append(task)
    output_text = "\n".join(output_lines)
    print(output_text)
    if not args.no_clipboard:
        if not copy_to_clipboard(output_text):
            print("Warning: clipboard copy failed.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
