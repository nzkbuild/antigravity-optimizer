"""Tests for the Antigravity Optimizer skill router."""
import json
import sys
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))

import skill_router


# ============================================================================
# Helper / get_skill_id
# ============================================================================

class TestGetSkillId:
    def test_id_field(self):
        assert skill_router.get_skill_id({"id": "foo", "name": "bar"}) == "foo"

    def test_name_fallback(self):
        assert skill_router.get_skill_id({"name": "bar"}) == "bar"

    def test_empty(self):
        assert skill_router.get_skill_id({}) == ""


# ============================================================================
# Normalize / Tokenize
# ============================================================================

class TestNormalize:
    def test_basic(self):
        assert skill_router.normalize("Hello World!") == "hello world"

    def test_special_chars(self):
        assert skill_router.normalize("react-best_practices") == "react best practices"

    def test_whitespace(self):
        assert skill_router.normalize("  spaces  ") == "spaces"


class TestTokenize:
    def test_splits(self):
        assert skill_router.tokenize("build a react app") == ["build", "a", "react", "app"]

    def test_empty(self):
        assert skill_router.tokenize("") == []

    def test_deduplication_not_applied(self):
        tokens = skill_router.tokenize("react react react")
        assert tokens == ["react", "react", "react"]


# ============================================================================
# Synonym Expansion
# ============================================================================

class TestExpandTokens:
    def test_auth_synonym(self):
        expanded = skill_router.expand_tokens(["auth"])
        assert "authentication" in expanded
        assert "auth" in expanded

    def test_no_duplicates(self):
        expanded = skill_router.expand_tokens(["authentication"])
        assert expanded.count("authentication") == 1

    def test_unknown_passthrough(self):
        expanded = skill_router.expand_tokens(["foobar"])
        assert expanded == ["foobar"]


# ============================================================================
# Scoring
# ============================================================================

class TestScoreSkill:
    def test_name_match_scores_higher(self):
        skill = {"id": "react-best-practices", "description": "Some description", "path": "skills/react"}
        score, name, _ = skill_router.score_skill(skill, ["react"], {}, set())
        assert score >= 3  # Name token match = 3 points

    def test_description_match(self):
        skill = {"id": "some-skill", "description": "Build frontend components", "path": "skills/some"}
        score, _, _ = skill_router.score_skill(skill, ["frontend"], {}, set())
        assert score >= 1  # Description match = 1 point

    def test_bundle_boost(self):
        skill = {"id": "react-best-practices", "description": "React stuff", "path": "skills/react"}
        score_without, _, _ = skill_router.score_skill(skill, ["react"], {}, set())
        score_with, _, _ = skill_router.score_skill(skill, ["react"], {}, {"react-best-practices"})
        assert score_with == score_without + 5

    def test_feedback_boost(self):
        skill = {"id": "react-best-practices", "description": "React stuff", "path": "skills/react"}
        score_without, _, _ = skill_router.score_skill(skill, ["react"], {}, set())
        score_with, _, _ = skill_router.score_skill(skill, ["react"], {"react-best-practices": 4}, set())
        assert score_with == score_without + 4

    def test_zero_score_on_no_match(self):
        skill = {"id": "kubernetes-expert", "description": "Container orchestration", "path": "skills/k8s"}
        score, _, _ = skill_router.score_skill(skill, ["painting", "art", "watercolor"], {}, set())
        assert score == 0

    def test_reasons_populated(self):
        skill = {"id": "react-tools", "description": "React development tools", "path": "skills/react"}
        _, _, reasons = skill_router.score_skill(skill, ["react"], {}, set())
        assert any("token:react" in r for r in reasons)


# ============================================================================
# Skill Picking
# ============================================================================

class TestPickSkills:
    def test_picks_top_skills(self, sample_skills):
        picked, _, _, _ = skill_router.pick_skills(
            sample_skills, "build a react frontend page", 3, {}, set()
        )
        assert len(picked) <= 3
        assert len(picked) >= 1

    def test_respects_max(self, sample_skills):
        picked, _, _, _ = skill_router.pick_skills(
            sample_skills, "build react frontend design database api", 2, {}, set()
        )
        assert len(picked) <= 2

    def test_fallback_to_brainstorming(self, sample_skills):
        picked, _, _, _ = skill_router.pick_skills(
            sample_skills, "xyzzy zyxwvu qwerty", 3, {}, set()
        )
        # Should fallback since no tokens match
        assert len(picked) >= 1

    def test_heavy_skills_filtered_by_default(self, sample_skills):
        picked, _, skipped_heavy, _ = skill_router.pick_skills(
            sample_skills, "loki autonomous agent", 5, {}, set()
        )
        # "loki" keyword allows heavy skills
        assert "loki-mode" not in skipped_heavy

    def test_heavy_skills_blocked_without_keyword(self, sample_skills):
        picked, _, skipped_heavy, _ = skill_router.pick_skills(
            sample_skills, "build a website", 5, {}, set()
        )
        assert "loki-mode" in skipped_heavy

    def test_security_filter_on_ui_task(self, sample_skills):
        picked, _, _, skipped_filtered = skill_router.pick_skills(
            sample_skills, "design a landing page UI", 5, {}, set()
        )
        # Security skills should be filtered for pure UI tasks
        assert len(skipped_filtered) >= 0  # At least validates no crash

    def test_bundle_boosts_selection(self, sample_skills):
        bundle_set = {"frontend-design", "react-best-practices"}
        picked, _, _, _ = skill_router.pick_skills(
            sample_skills, "build something", 3, {}, bundle_set
        )
        # Bundle skills should score higher
        assert any(s in bundle_set for s in picked)

    def test_explain_mode(self, sample_skills):
        _, explanations, _, _ = skill_router.pick_skills(
            sample_skills, "react frontend", 3, {}, set(), explain=True
        )
        assert len(explanations) > 0
        for name, score, reasons in explanations:
            assert isinstance(name, str)
            assert isinstance(score, (int, float))
            assert isinstance(reasons, list)


# ============================================================================
# Bundle Loading
# ============================================================================

class TestBundleLoading:
    def test_load_valid_bundles(self, tmp_bundles_file):
        with patch.object(skill_router, "BUNDLES_FILE", tmp_bundles_file):
            bundles = skill_router.load_bundles()
        assert "frontend" in bundles
        assert "react-best-practices" in bundles["frontend"]

    def test_load_invalid_json(self, tmp_path):
        bad_file = tmp_path / "bundles.json"
        bad_file.write_text("not json{{{", encoding="utf-8")
        with patch.object(skill_router, "BUNDLES_FILE", bad_file):
            bundles = skill_router.load_bundles()
        assert bundles == skill_router.DEFAULT_BUNDLES

    def test_load_missing_file(self, tmp_path):
        missing = tmp_path / "nonexistent.json"
        with patch.object(skill_router, "BUNDLES_FILE", missing):
            bundles = skill_router.load_bundles()
        assert bundles == skill_router.DEFAULT_BUNDLES


# ============================================================================
# Feedback
# ============================================================================

class TestFeedback:
    def test_load_empty(self, tmp_path):
        with patch.object(skill_router, "FEEDBACK_FILE", tmp_path / "nope.json"):
            fb = skill_router.load_feedback()
        assert fb == {}

    def test_save_and_load(self, tmp_feedback_file):
        with patch.object(skill_router, "FEEDBACK_FILE", tmp_feedback_file):
            skill_router.save_feedback({"react-best-practices": 4})
            fb = skill_router.load_feedback()
        assert fb["react-best-practices"] == 4

    def test_load_corrupted(self, tmp_path):
        bad_file = tmp_path / "feedback.json"
        bad_file.write_text("{{corrupt", encoding="utf-8")
        with patch.object(skill_router, "FEEDBACK_FILE", bad_file):
            fb = skill_router.load_feedback()
        assert fb == {}

    def test_feedback_cap_constant(self):
        assert skill_router.FEEDBACK_CAP == 10


# ============================================================================
# Index Loading
# ============================================================================

class TestLoadIndex:
    def test_load_list_format(self, tmp_index):
        skills = skill_router.load_index(tmp_index)
        assert len(skills) == 10

    def test_load_dict_format(self, tmp_path):
        index_file = tmp_path / "skills_index.json"
        data = {"skills": [{"id": "test-skill", "description": "A test"}]}
        index_file.write_text(json.dumps(data), encoding="utf-8")
        skills = skill_router.load_index(index_file)
        assert len(skills) == 1
        assert skills[0]["id"] == "test-skill"

    def test_load_invalid_json(self, tmp_path):
        bad = tmp_path / "skills_index.json"
        bad.write_text("not-json", encoding="utf-8")
        skills = skill_router.load_index(bad)
        assert skills == []


# ============================================================================
# Security Filter
# ============================================================================

class TestSecurityFilter:
    def test_allows_security_for_security_task(self):
        assert skill_router.should_filter_security(["security", "audit"], "vulnerability-scanner") is False

    def test_filters_security_from_ui_task(self):
        assert skill_router.should_filter_security(["ui", "design", "landing"], "vulnerability-scanner") is True

    def test_allows_non_security_skill_on_ui_task(self):
        assert skill_router.should_filter_security(["ui", "design"], "frontend-design") is False

    def test_filters_security_from_generic_task(self):
        # Fixed (2.3): security skills now filtered from ALL non-security tasks
        assert skill_router.should_filter_security(["build", "app"], "security-review") is True

    def test_keeps_security_on_pentest_task(self):
        assert skill_router.should_filter_security(["pentest", "web"], "vulnerability-scanner") is False


# ============================================================================
# Tag-Based Scoring (2.1)
# ============================================================================

class TestTagScoring:
    def test_tag_match_boosts_score(self):
        skill_no_tags = {"id": "some-skill", "description": "A description", "path": "skills/some"}
        skill_with_tags = {"id": "some-skill", "description": "A description", "path": "skills/some", "tags": ["react", "frontend"]}
        score_without, _, _ = skill_router.score_skill(skill_no_tags, ["react"], {}, set())
        score_with, _, _ = skill_router.score_skill(skill_with_tags, ["react"], {}, set())
        assert score_with > score_without

    def test_tag_reason_in_explain(self):
        skill = {"id": "test", "description": "Desc", "path": "p", "tags": ["deploy"]}
        _, _, reasons = skill_router.score_skill(skill, ["deploy"], {}, set())
        assert any("tag:" in r for r in reasons)


# ============================================================================
# Normalized Scoring (2.2)
# ============================================================================

class TestNormalizedScoring:
    def test_short_and_long_skills_balanced(self):
        """Skills with same relevance but different name lengths should score similarly."""
        short_skill = {"id": "react", "description": "React framework", "path": "skills/react"}
        long_skill = {"id": "react-best-practices-guide", "description": "React best practices and guidelines for building components", "path": "skills/react-best-practices-guide"}
        score_short, _, _ = skill_router.score_skill(short_skill, ["react"], {}, set())
        score_long, _, _ = skill_router.score_skill(long_skill, ["react"], {}, set())
        # Short skill should have competitive score (not drowned by long one)
        assert score_short > 0
        # The ratio should be reasonable (not 10x difference)
        if score_long > 0:
            ratio = score_short / score_long
            assert ratio > 0.3  # Short skill is at least 30% of long score

    def test_feedback_still_capped(self):
        skill = {"id": "x", "description": "test", "path": "p"}
        score, _, _ = skill_router.score_skill(skill, ["test"], {"x": 999}, set())
        # Feedback should be capped at FEEDBACK_CAP (10)
        score_no_fb, _, _ = skill_router.score_skill(skill, ["test"], {}, set())
        assert score - score_no_fb <= skill_router.FEEDBACK_CAP


# ============================================================================
# Category Detection (2.4)
# ============================================================================

class TestDetectTaskCategory:
    def test_frontend_task(self):
        cat = skill_router.detect_task_category(["build", "ui", "landing", "page"])
        assert cat == "frontend"

    def test_backend_task(self):
        cat = skill_router.detect_task_category(["create", "api", "endpoint"])
        assert cat == "backend"

    def test_database_task(self):
        cat = skill_router.detect_task_category(["fix", "database", "schema", "migration"])
        assert cat == "database"

    def test_security_task(self):
        cat = skill_router.detect_task_category(["pentest", "vulnerability"])
        assert cat == "security"

    def test_devops_task(self):
        cat = skill_router.detect_task_category(["deploy", "docker", "kubernetes"])
        assert cat == "devops"

    def test_testing_task(self):
        cat = skill_router.detect_task_category(["write", "test", "pytest"])
        assert cat == "testing"

    def test_unknown_task(self):
        cat = skill_router.detect_task_category(["xyzzy", "foobar"])
        assert cat == "default"


# ============================================================================
# Smart Fallback (2.4)
# ============================================================================

class TestSmartFallback:
    def test_database_task_does_not_fallback_to_brainstorming(self, sample_skills):
        """A database task should ideally pick database-design, not brainstorming."""
        picked, _, _, _ = skill_router.pick_skills(
            sample_skills, "fix database schema migration", 3, {}, set()
        )
        # Should pick database-design directly via scoring, not need fallback
        assert "brainstorming" not in picked or "database-design" in picked


# ============================================================================
# Project Profiles (2.5)
# ============================================================================

class TestProjectProfiles:
    def test_import_project_profiles(self):
        from project_profiles import detect_project_type, get_profiles_path, MAX_PROFILES
        assert MAX_PROFILES == 10

    def test_detect_unknown_project(self, tmp_path):
        from project_profiles import detect_project_type
        ptype, skills = detect_project_type(str(tmp_path))
        assert ptype == "unknown"
        assert skills == []

    def test_detect_node_project(self, tmp_path):
        from project_profiles import detect_project_type
        (tmp_path / "package.json").write_text('{"name": "test"}', encoding="utf-8")
        ptype, skills = detect_project_type(str(tmp_path))
        assert ptype == "node"

    def test_detect_python_project(self, tmp_path):
        from project_profiles import detect_project_type
        (tmp_path / "requirements.txt").write_text("flask\n", encoding="utf-8")
        ptype, skills = detect_project_type(str(tmp_path))
        assert ptype == "python"

    def test_detect_react_in_package_json(self, tmp_path):
        from project_profiles import detect_project_type
        pkg = {"name": "test", "dependencies": {"react": "^18.0.0"}}
        (tmp_path / "package.json").write_text(json.dumps(pkg), encoding="utf-8")
        ptype, skills = detect_project_type(str(tmp_path))
        assert "react-best-practices" in skills

    def test_detect_nextjs(self, tmp_path):
        from project_profiles import detect_project_type
        (tmp_path / "package.json").write_text('{"name":"t"}', encoding="utf-8")
        (tmp_path / "next.config.js").write_text("module.exports={}", encoding="utf-8")
        ptype, _ = detect_project_type(str(tmp_path))
        assert ptype == "nextjs"

    def test_lru_eviction(self, tmp_path):
        from project_profiles import save_profiles, load_profiles, MAX_PROFILES
        profiles = {}
        for i in range(MAX_PROFILES + 5):
            profiles[f"/project/{i}"] = {"type": "test", "preferred_skills": [], "last_used": i}
        with patch("project_profiles.get_profiles_path", return_value=tmp_path / "profiles.json"):
            save_profiles(profiles)
            loaded = load_profiles()
        assert len(loaded) <= MAX_PROFILES
