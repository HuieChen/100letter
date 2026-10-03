"""Temporary production fixtures only; never game/native acceptance evidence."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


studio = module("studio", ROOT / "tools/studio.py")
pipeline = module("pipeline", ROOT / "tools/studio/pipeline.py")


class ProductionPipelineTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = {"engine": {"name": "Godot", "version": "4.7.2", "language": "GDScript", "source_root": "scripts/rebuild", "entry": "scenes/final_slice.tscn"},
                        "upstream_revision": "a" * 40, "execution": "sequential_role_passes", "phase": "polish", "phases": ["polish", "release"],
                        "departments": {role: {"parent": "producer", "task": "Fixture review responsibility", "write_domains": ["scripts/book.gd"]} for role in ["ui-programmer", "qa-lead"]}}
        self.board = {"active_story": "BOOK", "stories": ["production/epics/story-book.json", "production/epics/story-bag.json"], "open_bugs": []}
        self.story = {"id": "BOOK", "chain": "book", "state": "review", "owner": "ui-programmer", "reviews_required": ["qa-lead"], "depends_on": [],
                      "acceptance": [{"id": "AC1", "requirement": "Visible cross", "check": "Actual click and screenshot"}],
                      "inputs": ["design/fixture.md"], "files": ["scripts/book.gd"], "completion": None}
        self.bag = {**copy.deepcopy(self.story), "id": "BAG", "chain": "bag", "state": "queued", "depends_on": ["BOOK"]}
        self.put("project.yaml", self.project)
        self.put("production/studio-board.json", self.board)
        self.put("production/epics/story-book.json", self.story)
        self.put("production/epics/story-bag.json", self.bag)
        self.put("tools/studio/upstream.lock.json", {"revision": "a" * 40, "vendor_root": "third_party/fixture"})
        self.put("tools/studio/config.json", {"chains": {"book": {}, "bag": {}}})
        for name in ["tools/studio.py", "tools/studio/pipeline.py", "scripts/book.gd", "design/fixture.md"]:
            self.text(name, "isolated fixture only")
        for role in ["producer", "ui-programmer", "qa-lead"]:
            self.text("third_party/fixture/.claude/agents/" + role + ".md", "fixture role definition")
        self.api = SimpleNamespace(verify=lambda root: None, within=studio.within, digest=studio.digest, source_digest=studio.source_digest,
                                   artifact=studio.artifact, fingerprint=studio.fingerprint,
                                   gate=lambda root, chain, evidence: {"blockers": [] if evidence.get("actual_native_checks") else ["Native fixture check absent"]})
        self.text("evidence/observed.txt", "Synthetic review evidence; no actual game assertion")
        self.put("evidence/engine.json", {"actual_native_checks": True})

    def text(self, name, value):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value, encoding="utf-8")

    def put(self, name, value):
        self.text(name, json.dumps(value))

    def review(self):
        _, _, stories = pipeline.state(self.root, self.api)
        value = {"role": "qa-lead", "chain": "book", "basis": pipeline.basis(self.root, stories["BOOK"], self.api),
                 "execution": "sequential_role_passes", "observed": "Synthetic fixture observation, not native evidence",
                 "verdict": "PASS", "findings": [], "criterion_results": {"AC1": {"status": "PASS", "observed": "Fixture cross click"}},
                 "artifacts": [{"path": "evidence/observed.txt", "sha256": studio.digest(self.root / "evidence/observed.txt")}]}
        self.put("evidence/review.json", value)
        return value

    def finish(self, evidence="evidence/engine.json", reviews=None):
        return pipeline.finish(self.root, "book", evidence, reviews if reviews is not None else ["evidence/review.json"], self.api)

    def test_ready_has_one_active_story_and_does_not_claim_completion(self):
        result = pipeline.ready(self.root, "book", self.api)
        self.assertEqual(result["status"], "READY_FOR_WORK")
        self.assertTrue(result["completion_is_not_implied"])
        self.assertEqual(pipeline.ready(self.root, "bag", self.api)["status"], "NOT_COMPLETE")

    def test_dispatch_materializes_bounded_briefs_without_spawning(self):
        result = pipeline.dispatch(self.root, "book", self.api)
        self.assertEqual(result["spawned_agents"], 0)
        self.assertEqual(len(result["briefs"]), 2)
        for brief in result["briefs"]:
            self.assertEqual(studio.digest(self.root / brief["brief"]), brief["sha256"])
        self.assertIn("no subagent launched", (self.root / result["briefs"][0]["brief"]).read_text(encoding="utf-8"))

    def test_unknown_role_missing_criteria_and_self_review_are_rejected(self):
        for update in [{"owner": "unknown"}, {"acceptance": []}, {"reviews_required": ["ui-programmer"]}]:
            self.put("production/epics/story-book.json", {**self.story, **update})
            with self.assertRaises(ValueError):
                pipeline.state(self.root, self.api)

    def test_cyclic_dependencies_and_missing_inputs_are_rejected(self):
        self.put("production/epics/story-book.json", {**self.story, "depends_on": ["BAG"]})
        with self.assertRaisesRegex(ValueError, "Cyclic"):
            pipeline.state(self.root, self.api)
        self.put("production/epics/story-book.json", {**self.story, "inputs": ["design/missing.md"]})
        with self.assertRaisesRegex(ValueError, "Missing story input"):
            pipeline.state(self.root, self.api)

    def test_missing_review_or_native_evidence_cannot_finish(self):
        self.assertEqual(self.finish(reviews=[])["status"], "NOT_COMPLETE")
        self.review()
        self.assertEqual(self.finish(evidence=None)["status"], "NOT_COMPLETE")
        self.put("evidence/engine.json", {})
        self.assertEqual(self.finish()["status"], "NOT_COMPLETE")

    def test_rework_not_assessed_duplicate_and_unassigned_reviews_reject(self):
        baseline = self.review()
        for update in [{"verdict": "REWORK"}, {"verdict": "NOT_ASSESSED"}, {"role": "producer"}, {"findings": ["Unresolved blocker"]}]:
            self.put("evidence/review.json", {**baseline, **update})
            self.assertEqual(self.finish()["status"], "NOT_COMPLETE")
        self.put("evidence/review.json", baseline)
        self.assertEqual(self.finish(reviews=["evidence/review.json"] * 2)["status"], "NOT_COMPLETE")

    def test_unchecked_acceptance_cannot_be_hidden_behind_pass_verdict(self):
        baseline = self.review()
        self.put("evidence/review.json", {**baseline, "criterion_results": {}})
        self.assertEqual(self.finish()["status"], "NOT_COMPLETE")
        self.put("evidence/review.json", {**baseline, "criterion_results": {"AC1": {"status": "NOT_ASSESSED", "observed": "No actual input"}}})
        self.assertEqual(self.finish()["status"], "NOT_COMPLETE")

    def test_changed_source_or_design_makes_review_stale(self):
        self.review()
        self.text("scripts/book.gd", "Changed implementation")
        self.assertEqual(self.finish()["status"], "NOT_COMPLETE")
        self.review()
        self.text("design/fixture.md", "Changed design")
        self.assertEqual(self.finish()["status"], "NOT_COMPLETE")

    def test_checkout_line_endings_do_not_invalidate_review_basis(self):
        path = self.root / "design/fixture.md"
        path.write_bytes(b"Same input\nSecond line\n")
        self.review()
        path.write_bytes(b"Same input\r\nSecond line\r\n")
        self.assertEqual(self.finish()["status"], "READY_FOR_RECORDED_HANDOFF")

    def test_adapter_logic_change_invalidates_review_basis(self):
        self.review()
        self.text("tools/studio.py", "Changed validation logic")
        self.assertEqual(self.finish()["status"], "NOT_COMPLETE")

    def test_changed_evidence_or_missing_observation_rejects(self):
        baseline = self.review()
        self.text("evidence/observed.txt", "Changed artifact")
        self.assertEqual(self.finish()["status"], "NOT_COMPLETE")
        self.review()
        self.put("evidence/review.json", {**baseline, "observed": ""})
        self.assertEqual(self.finish()["status"], "NOT_COMPLETE")

    def test_failed_handoff_does_not_write_or_advance_story(self):
        before = (self.root / "production/studio-board.json").read_bytes()
        result = pipeline.handoff(self.root, "book", None, [], self.api)
        self.assertEqual(result["status"], "NOT_COMPLETE")
        self.assertEqual((self.root / "production/studio-board.json").read_bytes(), before)
        self.assertFalse((self.root / "production/qa/handoffs").exists())

    def test_valid_fixture_handoff_records_receipt_and_rejects_stale_dependency(self):
        self.review()
        result = pipeline.handoff(self.root, "book", "evidence/engine.json", ["evidence/review.json"], self.api)
        self.assertEqual(result["next_story"], "BAG")
        self.assertEqual(pipeline.ready(self.root, "bag", self.api)["status"], "READY_FOR_WORK")
        self.text("scripts/book.gd", "New source after acceptance")
        result = pipeline.ready(self.root, "bag", self.api)
        self.assertEqual(result["status"], "NOT_COMPLETE")
        self.assertIn("Dependency runtime evidence is stale: BOOK", result["blockers"])

    def test_impact_routes_shared_changes_and_blocks_path_escape(self):
        result = pipeline.impact(self.root, ["scripts/book.gd"], self.api)
        self.assertEqual(result["affected_stories"], ["BAG", "BOOK"])
        self.assertEqual(result["coordinator"], "producer")
        self.assertFalse(result["messages_sent"])
        with self.assertRaises(ValueError):
            pipeline.impact(self.root, ["../outside.gd"], self.api)

    def test_engine_migration_and_revision_drift_reject(self):
        for update in [{"engine": {"name": "Unity"}}, {"upstream_revision": "b" * 40}]:
            self.put("project.yaml", {**self.project, **update})
            with self.assertRaises(ValueError):
                pipeline.state(self.root, self.api)


if __name__ == "__main__":
    unittest.main()
