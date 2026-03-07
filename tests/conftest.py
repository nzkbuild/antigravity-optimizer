"""Shared fixtures for Antigravity Optimizer tests."""
import json
import sys
from pathlib import Path

import pytest

# Add tools/ to path so we can import skill_router
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))


@pytest.fixture
def sample_skills():
    """Minimal skill index for testing."""
    return [
        {"id": "react-best-practices", "name": "react-best-practices", "description": "React and Next.js best practices for frontend development", "path": "skills/react-best-practices", "category": "Development"},
        {"id": "frontend-design", "name": "frontend-design", "description": "Create high-quality frontend interfaces and web components", "path": "skills/frontend-design", "category": "Design"},
        {"id": "database-design", "name": "database-design", "description": "Design database schemas and optimize queries", "path": "skills/database-design", "category": "Development"},
        {"id": "api-patterns", "name": "api-patterns", "description": "REST API design patterns and best practices", "path": "skills/api-patterns", "category": "Development"},
        {"id": "vulnerability-scanner", "name": "vulnerability-scanner", "description": "Scan for security vulnerabilities in web applications", "path": "skills/vulnerability-scanner", "category": "Security"},
        {"id": "security-review", "name": "security-review", "description": "Review code for security issues and best practices", "path": "skills/security-review", "category": "Security"},
        {"id": "brainstorming", "name": "brainstorming", "description": "Brainstorm ideas before starting any work", "path": "skills/brainstorming", "category": "General"},
        {"id": "copywriting", "name": "copywriting", "description": "Write compelling copy for marketing and landing pages", "path": "skills/copywriting", "category": "Business"},
        {"id": "loki-mode", "name": "loki-mode", "description": "Autonomous multi-agent orchestration mode", "path": "skills/loki-mode", "category": "Workflow"},
        {"id": "api-security-best-practices", "name": "api-security-best-practices", "description": "API security patterns including authentication and authorization", "path": "skills/api-security-best-practices", "category": "Security"},
    ]


@pytest.fixture
def tmp_index(tmp_path, sample_skills):
    """Write sample skills to a temporary index file."""
    index_file = tmp_path / "skills_index.json"
    index_file.write_text(json.dumps(sample_skills), encoding="utf-8")
    return index_file


@pytest.fixture
def tmp_feedback_file(tmp_path):
    """Return a path for a temporary feedback file."""
    return tmp_path / ".router_feedback.json"


@pytest.fixture
def tmp_bundles_file(tmp_path):
    """Write sample bundles to a temp file."""
    bundles = {
        "frontend": ["frontend-design", "react-best-practices"],
        "backend": ["database-design", "api-patterns"],
        "security": ["vulnerability-scanner", "security-review"],
    }
    bundles_file = tmp_path / "bundles.json"
    bundles_file.write_text(json.dumps(bundles), encoding="utf-8")
    return bundles_file
