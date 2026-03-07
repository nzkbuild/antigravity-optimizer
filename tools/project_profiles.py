"""LRU Project Profiles for the Antigravity Optimizer.

Auto-detects project type by scanning for marker files and applies
skill boosts based on project context. Stores per-project preferences
in a JSON file with LRU eviction (max 10 projects).
"""
import json
import os
from pathlib import Path

MAX_PROFILES = 10

# Project type markers: {marker_file: (project_type, preferred_skills)}
PROJECT_MARKERS = {
    "package.json": ("node", ["frontend-design", "react-best-practices", "test-driven-development"]),
    "tsconfig.json": ("typescript", ["typescript-expert", "react-best-practices"]),
    "go.mod": ("go", ["api-patterns", "test-driven-development"]),
    "Cargo.toml": ("rust", ["test-driven-development"]),
    "pyproject.toml": ("python", ["test-driven-development"]),
    "requirements.txt": ("python", ["test-driven-development"]),
    "setup.py": ("python", ["test-driven-development"]),
    "Gemfile": ("ruby", ["test-driven-development"]),
    "pom.xml": ("java", ["test-driven-development"]),
    "docker-compose.yml": ("docker", ["docker-expert"]),
    "Dockerfile": ("docker", ["docker-expert"]),
    ".terraform": ("terraform", ["terraform-expert"]),
}

# Refine detection with secondary markers
SECONDARY_MARKERS = {
    "next.config.js": "nextjs",
    "next.config.ts": "nextjs",
    "next.config.mjs": "nextjs",
    "vite.config.ts": "vite",
    "vite.config.js": "vite",
    "angular.json": "angular",
    "vue.config.js": "vue",
    "svelte.config.js": "svelte",
}


def get_profiles_path():
    """Return path to project profiles JSON file."""
    codex_home = os.getenv("CODEX_HOME", "").strip()
    if codex_home:
        return Path(codex_home) / ".project_profiles.json"
    return Path.home() / ".codex" / ".project_profiles.json"


def load_profiles():
    """Load project profiles from disk."""
    path = get_profiles_path()
    if not path.exists():
        return {}
    try:
        with path.open("r", encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict):
            return data
    except Exception:
        pass
    return {}


def save_profiles(profiles):
    """Save project profiles with LRU eviction."""
    path = get_profiles_path()
    path.parent.mkdir(parents=True, exist_ok=True)

    # LRU eviction: keep only MAX_PROFILES most recent
    if len(profiles) > MAX_PROFILES:
        sorted_keys = sorted(
            profiles.keys(),
            key=lambda k: profiles[k].get("last_used", 0),
            reverse=True,
        )
        profiles = {k: profiles[k] for k in sorted_keys[:MAX_PROFILES]}

    with path.open("w", encoding="utf-8") as f:
        json.dump(profiles, f, indent=2, sort_keys=True)


def detect_project_type(project_dir=None):
    """Detect project type by scanning for marker files in CWD."""
    cwd = Path(project_dir) if project_dir else Path.cwd()
    detected_type = "unknown"
    preferred_skills = []

    for marker, (ptype, skills) in PROJECT_MARKERS.items():
        marker_path = cwd / marker
        if marker_path.exists():
            detected_type = ptype
            preferred_skills = list(skills)
            break

    # Refine with secondary markers
    for marker, framework in SECONDARY_MARKERS.items():
        if (cwd / marker).exists():
            detected_type = framework
            break

    # Check for React in package.json
    if detected_type in ("node", "nextjs", "vite"):
        pkg_json = cwd / "package.json"
        if pkg_json.exists():
            try:
                with pkg_json.open("r", encoding="utf-8") as f:
                    pkg = json.load(f)
                deps = {}
                deps.update(pkg.get("dependencies", {}))
                deps.update(pkg.get("devDependencies", {}))
                if "react" in deps:
                    if "react-best-practices" not in preferred_skills:
                        preferred_skills.append("react-best-practices")
                if "vue" in deps:
                    detected_type = "vue"
                if "next" in deps:
                    detected_type = "nextjs"
                    if "nextjs-app-router-patterns" not in preferred_skills:
                        preferred_skills.append("nextjs-app-router-patterns")
            except Exception:
                pass

    return detected_type, preferred_skills


def get_project_profile(project_dir=None):
    """Get or create a profile for the current project."""
    import time

    cwd = str(Path(project_dir) if project_dir else Path.cwd())
    profiles = load_profiles()

    if cwd in profiles:
        # Update last_used timestamp
        profiles[cwd]["last_used"] = int(time.time())
        save_profiles(profiles)
        return profiles[cwd]

    # Create new profile
    project_type, preferred_skills = detect_project_type(project_dir)
    profile = {
        "type": project_type,
        "preferred_skills": preferred_skills,
        "last_used": int(time.time()),
        "feedback": {},
    }
    profiles[cwd] = profile
    save_profiles(profiles)
    return profile


def get_profile_boost_set(project_dir=None):
    """Return set of skill IDs that get a boost for this project."""
    profile = get_project_profile(project_dir)
    return set(profile.get("preferred_skills", []))
