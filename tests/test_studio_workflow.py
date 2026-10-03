"""Regression checks for evidence rejection, not tests of game usability."""
import copy
import importlib.util
import json
from pathlib import Path
import struct
import shutil
import tempfile
import unittest
import zlib

SPEC = importlib.util.spec_from_file_location("studio", Path(__file__).resolve().parents[1] / "tools/studio.py")
studio = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(studio)


class StudioGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "tools/studio").mkdir(parents=True)
        self.config = {"required_native_checks": ["normal_path", "visible_cross", "zh_en_layout"],
                       "chains": {"book": {"suite_name": "field_book"}}}
        self.write("tools/studio/config.json", json.dumps(self.config))
        self.write("project.godot", "fixture engine configuration")
        self.write("scripts/book.gd", "fixture source")
        self.write("tests/book.gd", "fixture test")
        self.write("evidence/result.json", json.dumps({"suite": "field_book", "checks": 5, "failures": []}))
        self.write("evidence/engine.log", "fixture successful engine output")
        # Blank synthetic fixture exists only in the temporary test directory.
        self.write("evidence/fixture.png", self.png(1920, 1080))
        self.report = {"chain": "book", "source_fingerprint": studio.fingerprint(self.root),
                       "source_unchanged_during_run": True,
                       "engine": {"exit_code": 0, "checks": 5, "failures": [],
                                  "result": self.artifact("evidence/result.json"),
                                  "log": self.artifact("evidence/engine.log")},
                       "native_review": {"method": "os_input_visual_review", "reviewer": "fixture only",
                                         "observations": "Synthetic gate fixture, not game evidence",
                                         "checks": {key: "PASS" for key in self.config["required_native_checks"]},
                                         "screenshots": [self.artifact("evidence/fixture.png")]},
                       "unresolved_blockers": []}

    def write(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content if isinstance(content, bytes) else content.encode("utf-8"))

    def artifact(self, name):
        return {"path": name, "sha256": studio.digest(self.root / name)}

    @staticmethod
    def png(width, height):
        def chunk(kind, data):
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
        header = struct.pack(">IIBBBBB", width, height, 8, 0, 0, 0, 0)
        pixels = zlib.compress(b"\0" * ((width + 1) * height))
        return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", pixels) + chunk(b"IEND", b"")

    def rejected(self, report):
        result = studio.gate(self.root, "book", report)
        self.assertEqual(result["status"], "NOT_COMPLETE")
        self.assertTrue(result["blockers"])
        self.assertEqual(result["player_acceptance"], "NOT_INFERRED")
        return result

    def test_complete_metadata_satisfies_gate_without_claiming_player_acceptance(self):
        result = studio.gate(self.root, "book", self.report)
        self.assertEqual(result["status"], "READY_FOR_PHASE_REPORT")
        self.assertEqual(result["blockers"], [])
        self.assertEqual(result["player_acceptance"], "NOT_INFERRED")

    def test_passing_engine_without_native_review_is_rejected(self):
        report = copy.deepcopy(self.report)
        report["native_review"] = None
        self.rejected(report)

    def test_source_changed_after_capture_invalidates_evidence(self):
        self.write("scripts/book.gd", "changed source")
        result = self.rejected(self.report)
        self.assertIn("Source/test/art fingerprint is missing or stale", result["blockers"])

    def test_source_change_during_capture_is_rejected(self):
        report = copy.deepcopy(self.report)
        report["source_unchanged_during_run"] = False
        self.rejected(report)

    def test_changed_or_missing_artifacts_are_rejected(self):
        self.write("evidence/result.json", "{}")
        self.rejected(self.report)
        (self.root / "evidence/fixture.png").unlink()
        self.rejected(self.report)

    def test_unknown_or_failed_native_check_is_rejected(self):
        for value in ("NOT_ASSESSED", "FAIL", None):
            report = copy.deepcopy(self.report)
            report["native_review"]["checks"]["zh_en_layout"] = value
            self.rejected(report)

    def test_empty_or_failed_engine_check_is_rejected(self):
        for value in (0, True):
            report = copy.deepcopy(self.report)
            report["engine"]["checks"] = value
            self.rejected(report)
        report = copy.deepcopy(self.report)
        report["engine"]["exit_code"] = 1
        self.rejected(report)

    def test_wrong_suite_and_wrong_chain_are_rejected(self):
        report = copy.deepcopy(self.report)
        report["chain"] = "map"
        self.rejected(report)
        self.write("evidence/result.json", json.dumps({"suite": "map", "checks": 5, "failures": []}))
        report = copy.deepcopy(self.report)
        report["engine"]["result"] = self.artifact("evidence/result.json")
        self.rejected(report)

    def test_headless_review_and_unresolved_blocker_are_rejected(self):
        report = copy.deepcopy(self.report)
        report["native_review"]["method"] = "headless"
        self.rejected(report)
        report = copy.deepcopy(self.report)
        report["unresolved_blockers"] = ["Missing close control"]
        self.rejected(report)

    def test_path_escape_and_absolute_evidence_are_rejected(self):
        for name in ("../outside.png", str(self.root / "evidence/fixture.png"), "evidence/../../outside.png"):
            with self.assertRaises(ValueError):
                studio.within(self.root, name)

    def test_wrong_screenshot_size_is_rejected(self):
        self.write("evidence/fixture.png", self.png(1280, 720))
        report = copy.deepcopy(self.report)
        report["native_review"]["screenshots"] = [self.artifact("evidence/fixture.png")]
        self.rejected(report)

    def test_truncated_png_and_changed_upstream_are_rejected(self):
        self.write("evidence/fixture.png", self.png(1920, 1080)[:24])
        report = copy.deepcopy(self.report)
        report["native_review"]["screenshots"] = [self.artifact("evidence/fixture.png")]
        self.rejected(report)
        shutil.copytree(studio.ROOT / "third_party", self.root / "third_party")
        for name in ("upstream.lock.json", "config.json"):
            shutil.copy2(studio.ROOT / "tools/studio" / name, self.root / "tools/studio" / name)
        self.write("third_party/claude-code-game-studios/README.md", "changed upstream contents")
        with self.assertRaisesRegex(ValueError, "Upstream bytes changed"):
            studio.verify(self.root)


if __name__ == "__main__":
    unittest.main()
