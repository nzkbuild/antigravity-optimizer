#!/usr/bin/env python
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

# Python version check
if sys.version_info < (3, 8):
    print("Error: Python 3.8+ is required. You have Python {}.{}.{}".format(*sys.version_info[:3]), file=sys.stderr)
    print("Please upgrade Python from https://python.org/downloads/", file=sys.stderr)
    sys.exit(1)

try:
    from project_profiles import get_profile_boost_set
except ImportError:
    def get_profile_boost_set(project_dir=None):
        return set()

try:
    from routing_memory import (
        write_session_entry, write_diary_entry, recall,
        get_master_memory_boosts, archive_old_diaries,
    )
    HAS_MEMORY = True
except ImportError:
    HAS_MEMORY = False


DEFAULT_MAX_SKILLS = 3
MAX_SKILLS = 5  # Enforced cap for router output
MAX_TASK_LENGTH = 2000  # Prevent extremely long task text
FEEDBACK_CAP = 10  # Maximum absolute feedback score per skill
MIN_SCORE = 2
RELATIVE_THRESHOLD = 0.7
REPO_ROOT = Path(__file__).resolve().parents[1]
HEAVY_SKILLS = {"loki-mode"}

def resolve_skills_root():
    env_root = os.getenv("ANTIGRAVITY_SKILLS_ROOT", "").strip()
    if env_root:
        env_path = Path(env_root)
        if (env_path / "skills_index.json").exists():
            return env_path

    repo_root = REPO_ROOT / ".agent" / "skills"
    if (repo_root / "skills_index.json").exists():
        return repo_root

    codex_home = os.getenv("CODEX_HOME", "").strip()
    if not codex_home:
        codex_home = str(Path.home() / ".codex")
    codex_skills = Path(codex_home) / "skills"
    if (codex_skills / "skills_index.json").exists():
        return codex_skills

    return repo_root


SKILLS_ROOT = resolve_skills_root()
# Store feedback in a user-writable location to avoid permission issues
FEEDBACK_FILE = Path.home() / ".codex" / ".router_feedback.json"
BUNDLES_FILE = REPO_ROOT / "bundles.json"
DEFAULT_BUNDLES = {
    "frontend": ["frontend-design", "ui-ux-pro-max", "react-best-practices"],
    "backend": ["backend-dev-guidelines", "api-patterns", "database-design"],
    "marketing": ["copywriting", "page-cro", "seo-audit"],
    "security": ["vulnerability-scanner", "security-review", "api-security-best-practices"],
    "product": ["ai-product", "product-requirements", "brainstorming"],
}


def get_skill_id(skill):
    """Extract the canonical ID from a skill dict."""
    return skill.get("id") or skill.get("name") or ""


def load_bundles():
    """Load bundles from JSON file or return defaults."""
    if BUNDLES_FILE.exists():
        try:
            with BUNDLES_FILE.open("r", encoding="utf-8") as f:
                data = json.load(f)
            if isinstance(data, dict):
                return data
        except Exception as e:
            print(f"Warning: Failed to load bundles.json: {e}", file=sys.stderr)
    return DEFAULT_BUNDLES


def normalize(text):
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return text.strip()


def tokenize(text):
    return [t for t in normalize(text).split() if t]

# Lightweight synonym normalization to improve routing recall.
SYNONYM_MAP = {
    "auth": "authentication",
    "oauth": "authentication",
    "login": "authentication",
    "db": "database",
    "sql": "database",
    "ui": "frontend",
    "ux": "frontend",
    "perf": "performance",
    "opt": "optimization",
    "ops": "devops",
    "k8s": "kubernetes",
    "sec": "security",
    "cli": "command",
}

SECURITY_KEYWORDS = {
    "security", "vulnerability", "pentest", "penetration", "red-team", "redteam",
    "xss", "sqli", "sql-injection", "csrf", "bug-bounty", "owasp", "audit"
}

UI_KEYWORDS = {
    "ui", "ux", "design", "landing", "frontend", "website", "page", "component",
    "css", "style", "layout"
}

def expand_tokens(tokens):
    expanded = list(tokens)
    for token in tokens:
        mapped = SYNONYM_MAP.get(token)
        if mapped and mapped not in expanded:
            expanded.append(mapped)
    return expanded


# Category-aware fallback mapping (2.4)
CATEGORY_FALLBACKS = {
    "security": "security-review",
    "frontend": "frontend-design",
    "backend": "api-patterns",
    "database": "database-design",
    "devops": "docker-expert",
    "testing": "test-driven-development",
    "default": "brainstorming",
}

CATEGORY_KEYWORDS = {
    "security": SECURITY_KEYWORDS,
    "frontend": UI_KEYWORDS,
    "backend": {"api", "server", "endpoint", "rest", "graphql", "backend", "microservice"},
    "database": {"database", "db", "sql", "postgres", "mongo", "redis", "schema", "migration"},
    "devops": {"docker", "kubernetes", "k8s", "deploy", "ci", "cd", "pipeline", "terraform", "aws"},
    "testing": {"test", "tdd", "qa", "playwright", "jest", "pytest", "coverage"},
}


def should_filter_security(task_tokens, skill_name):
    """Filter security skills from non-security tasks."""
    task_has_security = any(t in SECURITY_KEYWORDS for t in task_tokens)
    if task_has_security:
        return False  # Security task — keep security skills
    name = (skill_name or "").lower()
    is_security_skill = any(k in name for k in SECURITY_KEYWORDS)
    return is_security_skill  # Filter security skills from non-security tasks


def detect_task_category(task_tokens):
    """Detect dominant task category for smart fallback."""
    best_cat = "default"
    best_count = 0
    for category, keywords in CATEGORY_KEYWORDS.items():
        overlap = sum(1 for t in task_tokens if t in keywords)
        if overlap > best_count:
            best_count = overlap
            best_cat = category
    return best_cat if best_count > 0 else "default"


def load_index(index_path):
    try:
        with index_path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        if isinstance(data, dict) and "skills" in data:
            skills = data["skills"]
        elif isinstance(data, list):
            skills = data
        else:
            skills = []
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in skills_index.json: {e}", file=sys.stderr)
        return []
    except Exception as e:
        print(f"Error: Failed to load skills index: {e}", file=sys.stderr)
        return []

    # Merge custom skills from .agent/skills/custom/ (4.1)
    custom_dir = Path.cwd() / ".agent" / "skills" / "custom"
    if custom_dir.exists():
        for skill_dir in custom_dir.iterdir():
            if skill_dir.is_dir():
                skill_md = skill_dir / "SKILL.md"
                if skill_md.exists():
                    skill_id = skill_dir.name
                    # Don't duplicate if already in index
                    if not any(get_skill_id(s) == skill_id for s in skills):
                        # Parse frontmatter for description
                        desc = _parse_skill_description(skill_md)
                        skills.append({
                            "id": skill_id,
                            "name": skill_id,
                            "description": desc,
                            "path": str(skill_dir),
                            "category": "Custom",
                            "source": "local",
                        })
    return skills


def _parse_skill_description(skill_md_path):
    """Extract description from SKILL.md frontmatter."""
    try:
        content = skill_md_path.read_text(encoding="utf-8")
        if content.startswith("---"):
            end = content.find("---", 3)
            if end > 0:
                frontmatter = content[3:end]
                for line in frontmatter.splitlines():
                    if line.strip().startswith("description:"):
                        return line.split(":", 1)[1].strip().strip('"').strip("'")
    except Exception:
        pass
    return "Custom skill (no description)"


def load_feedback():
    if not FEEDBACK_FILE.exists():
        return {}
    try:
        with FEEDBACK_FILE.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        if isinstance(data, dict):
            return data
    except Exception as e:
        print(f"Warning: Failed to load feedback file: {e}", file=sys.stderr)
    return {}


def save_feedback(feedback):
    FEEDBACK_FILE.parent.mkdir(parents=True, exist_ok=True)
    with FEEDBACK_FILE.open("w", encoding="utf-8") as handle:
        json.dump(feedback, handle, indent=2, sort_keys=True)


def score_skill(skill, task_tokens, feedback, bundle_set):
    name = get_skill_id(skill)
    description = skill.get("description") or ""
    path = skill.get("path") or ""
    tags = skill.get("tags") or []
    name_tokens = set(tokenize(name))
    desc_tokens = set(tokenize(description))
    path_tokens = set(tokenize(path))
    tag_tokens = set(t.lower() for t in tags)
    task_set = set(task_tokens)

    # Weighted overlap scoring
    name_overlap = len(task_set & (name_tokens | path_tokens))
    desc_overlap = len(task_set & desc_tokens)
    tag_overlap = len(task_set & tag_tokens)

    raw = (name_overlap * 3) + (desc_overlap * 1) + (tag_overlap * 2)

    # Normalize by skill token count to prevent length bias
    total_skill_tokens = len(name_tokens | desc_tokens | tag_tokens) or 1
    score = (raw / total_skill_tokens) * 10

    reasons = []
    for token in task_tokens:
        if token in name_tokens or token in path_tokens:
            if f"token:{token}" not in reasons:
                reasons.append(f"token:{token}")
        if token in desc_tokens:
            if f"desc:{token}" not in reasons:
                reasons.append(f"desc:{token}")
        if token in tag_tokens:
            if f"tag:{token}" not in reasons:
                reasons.append(f"tag:{token}")

    if name in bundle_set:
        score += 5
        reasons.append("bundle:+5")

    boost = feedback.get(name)
    if isinstance(boost, (int, float)):
        score += min(max(boost, -FEEDBACK_CAP), FEEDBACK_CAP)
        reasons.append(f"feedback:+{boost}")
    return score, name, reasons


def allow_heavy_skill(task_text):
    task_text = (task_text or "").lower()
    keywords = ["loki", "autonomous", "multi-agent", "multi agent", "agents", "swarm"]
    return any(k in task_text for k in keywords)


def pick_skills(skills, task, max_skills, feedback, bundle_set, explain=False):
    task_tokens = expand_tokens(tokenize(task))
    allow_heavy = allow_heavy_skill(task)
    scored = []
    skipped_heavy = []
    skipped_filtered = []
    for skill in skills:
        name = get_skill_id(skill)
        if (name in HEAVY_SKILLS) and (not allow_heavy):
            skipped_heavy.append(name)
            continue
        if should_filter_security(task_tokens, name):
            skipped_filtered.append(name)
            continue
        score, skill_name, reasons = score_skill(skill, task_tokens, feedback, bundle_set)
        scored.append((score, skill_name, reasons))

    scored.sort(key=lambda item: item[0], reverse=True)
    top_score = scored[0][0] if scored else 0

    picked = []
    explanations = []
    for score, name, reasons in scored:
        if len(picked) >= max_skills:
            break
        if score <= 0:
            continue
        if score >= max(MIN_SCORE, int(top_score * RELATIVE_THRESHOLD)):
            picked.append(name)
            if explain:
                explanations.append((name, score, reasons))

    if not picked:
        # Smart category-aware fallback (2.4)
        category = detect_task_category(task_tokens)
        fallback_name = CATEGORY_FALLBACKS.get(category, "brainstorming")
        fallback = next((get_skill_id(s) for s in skills if get_skill_id(s) == fallback_name), None)
        if not fallback:
            # Try brainstorming as final fallback
            fallback = next((get_skill_id(s) for s in skills if get_skill_id(s) == "brainstorming"), None)
        if fallback:
            picked = [fallback]
        else:
            picked = [scored[0][1]] if scored else []

    return picked, explanations, skipped_heavy, skipped_filtered


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
    """Cross-platform clipboard copy."""
    try:
        if os.name == "nt":
            # Windows: use PowerShell
            proc = subprocess.run(
                ["powershell", "-NoProfile", "-Command", "Set-Clipboard -Value ([Console]::In.ReadToEnd())"],
                input=text,
                text=True,
                capture_output=True,
            )
            return proc.returncode == 0
        elif shutil.which("pbcopy"):
            # macOS: use pbcopy
            proc = subprocess.run(["pbcopy"], input=text.encode(), capture_output=True)
            return proc.returncode == 0
        elif shutil.which("xclip"):
            # Linux: use xclip
            proc = subprocess.run(
                ["xclip", "-selection", "clipboard"],
                input=text.encode(),
                capture_output=True,
            )
            return proc.returncode == 0
        elif shutil.which("xsel"):
            # Linux fallback: use xsel
            proc = subprocess.run(
                ["xsel", "--clipboard", "--input"],
                input=text.encode(),
                capture_output=True,
            )
            return proc.returncode == 0
    except Exception:
        pass
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
        choices=sorted(load_bundles().keys()),
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
    parser.add_argument(
        "--no-profile",
        action="store_true",
        help="Disable project profile detection and boosting",
    )
    parser.add_argument(
        "--no-memory",
        action="store_true",
        help="Disable session memory and diary writing",
    )
    parser.add_argument(
        "--recall",
        type=str,
        metavar="QUERY",
        help="Search past routing sessions by keyword",
    )
    parser.add_argument(
        "--list-bundles",
        action="store_true",
        help="List all available skill bundles",
    )
    parser.add_argument(
        "--search",
        type=str,
        metavar="KEYWORD",
        help="Search skills by keyword in name/description",
    )
    parser.add_argument(
        "--info",
        type=str,
        metavar="SKILL_ID",
        help="Show detailed information about a specific skill",
    )
    parser.add_argument(
        "--why",
        action="store_true",
        help="Explain why each skill was selected (printed to stderr)",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    max_skills = max(1, min(args.max, MAX_SKILLS))
    task = " ".join(args.task or []).strip()

    index_path = SKILLS_ROOT / "skills_index.json"
    if not index_path.exists():
        print(f"Error: skills_index.json not found at {index_path}", file=sys.stderr)
        return 1

    skills = load_index(index_path)
    if not skills:
        print("Error: No skills found in index. Run setup.ps1 to install skills.", file=sys.stderr)
        return 1
    
    # Handle --list-bundles
    if args.list_bundles:
        bundles = load_bundles()
        print("=" * 50)
        print("AVAILABLE SKILL BUNDLES")
        print("=" * 50)
        for bundle_name, bundle_skills in sorted(bundles.items()):
            print(f"\n{bundle_name}:")
            for skill in bundle_skills:
                print(f"  - {skill}")
        print()
        print(f"Usage: activate-skills --bundle <name> \"your task\"")
        print("=" * 50)
        return 0
    
    # Handle --search
    if args.search:
        keyword = args.search.lower()
        matches = []
        for skill in skills:
            skill_id = get_skill_id(skill)
            desc = skill.get("description") or ""
            if keyword in skill_id.lower() or keyword in desc.lower():
                matches.append(skill)
        
        print("=" * 50)
        print(f"SEARCH RESULTS: '{args.search}'")
        print("=" * 50)
        if matches:
            print(f"Found {len(matches)} skills:\n")
            for skill in matches[:20]:  # Limit to 20 results
                skill_id = get_skill_id(skill) or "unknown"
                desc = skill.get("description") or "No description"
                # Truncate description
                if len(desc) > 60:
                    desc = desc[:57] + "..."
                print(f"  {skill_id}")
                print(f"    {desc}\n")
            if len(matches) > 20:
                print(f"  ... and {len(matches) - 20} more")
        else:
            print("No skills found matching that keyword.")
        print("=" * 50)
        return 0
    
    # Handle --info
    if args.info:
        skill_id = args.info.lower()
        found = None
        for skill in skills:
            sid = get_skill_id(skill).lower()
            if sid == skill_id:
                found = skill
                break
        
        if not found:
            print(f"Error: Skill '{args.info}' not found.", file=sys.stderr)
            print("Use --search to find skills.", file=sys.stderr)
            return 1
        
        print("=" * 50)
        print("SKILL INFORMATION")
        print("=" * 50)
        sid = get_skill_id(found)
        print(f"  ID:          {sid}")
        print(f"  Name:        {found.get('name', 'N/A')}")
        print(f"  Category:    {found.get('category', 'N/A')}")
        tags = found.get('tags')
        if tags:
            print(f"  Tags:        {', '.join(tags)}")
        print(f"  Source:      {found.get('source', 'N/A')}")
        print(f"  Path:        {found.get('path', 'N/A')}")
        context = found.get('context')
        if context:
            print(f"  Context:     {context}")
        allowed = found.get('allowed-tools')
        if allowed:
            print(f"  Tools:       {allowed}")
        arg_hint = found.get('argument-hint')
        if arg_hint:
            print(f"  Invocation:  /{sid} {arg_hint}")
        fb = load_feedback().get(sid)
        if fb:
            print(f"  Feedback:    {'+' if fb > 0 else ''}{fb}")
        print(f"  Risk:        {found.get('risk', 'N/A')}")
        print()
        print("  Description:")
        desc = found.get('description', 'No description available.')
        # Word wrap description
        words = desc.split()
        line = "    "
        for word in words:
            if len(line) + len(word) > 70:
                print(line)
                line = "    "
            line += word + " "
        if line.strip():
            print(line)
        print("=" * 50)
        return 0
    
    if args.verify:
        skills_dir = SKILLS_ROOT / "skills"
        if not skills_dir.exists():
            skills_dir = SKILLS_ROOT
        skill_paths = {str(p.parent.relative_to(SKILLS_ROOT).as_posix()) for p in skills_dir.rglob("SKILL.md")}
        index_paths = {item.get("path") for item in skills if isinstance(item, dict) and item.get("path")}
        missing_on_disk = sorted(index_paths - skill_paths)
        missing_in_index = sorted(skill_paths - index_paths)
        
        print("=" * 50)
        print("SKILLS VERIFICATION REPORT")
        print("=" * 50)
        print(f"Index entries:    {len(index_paths)}")
        print(f"Skill folders:    {len(skill_paths)}")
        print(f"Missing on disk:  {len(missing_on_disk)}")
        print(f"Missing in index: {len(missing_in_index)}")
        print()
        
        # Status assessment
        if len(missing_on_disk) == 0 and len(missing_in_index) == 0:
            print("Status: [OK] SYNCED - Index matches disk perfectly")
        elif len(missing_on_disk) > 0:
            print(f"Status: [!] MISMATCH - {len(missing_on_disk)} skills in index but not on disk")
            print("\nRecommendation: Run setup.ps1 (or setup.sh) to reinstall skills")
            if len(missing_on_disk) <= 10:
                print("\nMissing skills:")
                for skill in missing_on_disk:
                    print(f"  - {skill}")
        elif len(missing_in_index) > 0:
            print(f"Status: [!] EXTRA - {len(missing_in_index)} skill folders not in index")
            print("\nThese may be custom skills or stale directories.")
        
        print("=" * 50)
        return 0

    # Handle --recall (3.3) — no task required
    if args.recall:
        if not HAS_MEMORY:
            print("Error: Memory module not available.", file=sys.stderr)
            return 1
        results = recall(args.recall)
        if results:
            print(f"Found {len(results)} past sessions matching \"{args.recall}\":\n")
            for r in results:
                print(f"  {r['date']} {r['time']}: \"{r['task']}\" \u2192 {r['skills']}")
        else:
            print(f"No past sessions found matching \"{args.recall}\".")
        return 0

    if not task:
        print("Error: task text is required.", file=sys.stderr)
        return 1

    if len(task) > MAX_TASK_LENGTH:
        print(f"Error: Task too long ({len(task)} chars). Maximum is {MAX_TASK_LENGTH} characters.", file=sys.stderr)
        return 1

    if args.intake:
        task = run_intake(task)

    feedback = load_feedback()
    bundles = load_bundles()
    bundle_set = set(bundles.get(args.bundle or "", []))

    # Merge project profile boosts (2.5)
    if not args.no_profile:
        profile_boost = get_profile_boost_set()
        bundle_set = bundle_set | profile_boost

    # Apply master memory boosts/penalties (3.4)
    master_boost_set = set()
    master_avoid_set = set()
    if HAS_MEMORY and not args.no_memory:
        try:
            master_boost_set, master_avoid_set = get_master_memory_boosts()
            bundle_set = bundle_set | master_boost_set
        except Exception:
            pass


    
    # Validate bundle skills exist in index
    if args.bundle and bundle_set:
        skill_ids = {get_skill_id(s) for s in skills}
        missing_bundle_skills = bundle_set - skill_ids
        if missing_bundle_skills:
            print(f"Warning: Bundle '{args.bundle}' references skills not in index: {', '.join(sorted(missing_bundle_skills))}", file=sys.stderr)
    
    picked, explanations, skipped_heavy, skipped_filtered = pick_skills(
        skills, task, max_skills, feedback, bundle_set, explain=args.why
    )

    if args.feedback:
        skill_ids = {get_skill_id(s) for s in skills}
        for name in args.feedback:
            if name not in skill_ids:
                print(f"Warning: '{name}' not in skill index, skipping", file=sys.stderr)
                continue
            feedback[name] = min(feedback.get(name, 0) + 2, FEEDBACK_CAP)
        save_feedback(feedback)

    output_lines = []
    if picked:
        output_lines.append(" ".join(f"/{name}" for name in picked))
    output_lines.append(task)
    output_text = "\n".join(output_lines)
    print(output_text)
    if args.why:
        if skipped_heavy:
            print(
                f"[why] Skipped heavy skills: {', '.join(sorted(set(skipped_heavy)))}",
                file=sys.stderr,
            )
        if skipped_filtered:
            print(
                f"[why] Filtered skills (context mismatch): {', '.join(sorted(set(skipped_filtered)))}",
                file=sys.stderr,
            )
        for name, score, reasons in explanations:
            reason_text = ", ".join(reasons) if reasons else "no strong matches"
            print(f"[why] {name}: score={score} ({reason_text})", file=sys.stderr)
    if not args.no_clipboard:
        if not copy_to_clipboard(output_text):
            print("Warning: clipboard copy failed.", file=sys.stderr)

    # Write memory (3.1 + 3.2)
    if HAS_MEMORY and not args.no_memory:
        try:
            scores = [(name, score) for name, score, _ in explanations] if explanations else None
            write_session_entry(task, picked, args.bundle, scores)
            write_diary_entry(task, picked, args.bundle, scores)
        except Exception as e:
            print(f"Warning: Failed to write memory: {e}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
