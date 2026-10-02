"""Negative cases mutate only TemporaryDirectory copies, never user originals."""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from tools import check_locked_assets as gate
from tools import import_street_background as street_import

CODE_ROOT = Path(__file__).resolve().parents[1]
REPO = Path(os.environ.get("SOLMERE_ARCHIVE_ROOT", CODE_ROOT)).resolve()


@unittest.skipUnless((REPO / gate.STREET_ORIGINAL).is_file() and (REPO / gate.PACKAGE_DIR).is_dir(),
                     "Private archive not published; use ArchiveChecks with an explicit local ArchiveRoot.")
class LockedAssetGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="solmere-locked-assets-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for directory in (gate.PACKAGE_DIR, gate.PROJECT_DIR):
            shutil.copytree(REPO / directory, self.root / directory)
        # copytree preserves the original PSD's read-only attribute. Only this
        # disposable copy is made writable for corruption tests, never REPO.
        (self.root / gate.STREET_ORIGINAL).chmod(0o600)
        # copytree preserves the original PSD's read-only attribute. Only this
        # disposable copy is made writable for corruption tests, never REPO.
        (self.root / gate.STREET_ORIGINAL).chmod(0o600)
        (self.root / "docs").mkdir()
        shutil.copyfile(REPO / gate.INTEGRITY_FILE, self.root / gate.INTEGRITY_FILE)
        shutil.copyfile(REPO / gate.STREET_MANIFEST, self.root / gate.STREET_MANIFEST)
        (self.root / gate.STREET_PREVIEW).parent.mkdir(parents=True)
        shutil.copyfile(REPO / gate.STREET_PREVIEW, self.root / gate.STREET_PREVIEW)

    def issue(self, report, code, path_fragment):
        self.assertFalse(report["ok"])
        self.assertTrue(any(row["code"] == code and path_fragment in row["path"] + row["detail"]
                            for row in report["issues"]), report["issues"])

    def edit_record(self, edit):
        path = self.root / gate.INTEGRITY_FILE
        data = json.loads(path.read_text(encoding="utf-8"))
        edit(data)
        path.write_text(json.dumps(data), encoding="utf-8")

    def test_real_project_positive_is_read_only(self):
        paths = [REPO / gate.PACKAGE_DIR / row[0] for row in gate.PACKAGE_ASSETS]
        paths += [REPO / gate.PROJECT_DIR / row[1] for row in gate.PACKAGE_ASSETS + gate.ATTACHMENT_ASSETS]
        paths += [REPO / gate.STREET_ORIGINAL, REPO / gate.STREET_PREVIEW]
        before = {path: gate.sha256(path) for path in paths}
        report = gate.audit(REPO)
        self.assertTrue(report["ok"], report["issues"])
        self.assertEqual(24, len([row for row in report["checks"] if row["scope"] != "package_manifest"]))
        self.assertEqual(before, {path: gate.sha256(path) for path in paths})
        self.assertFalse(any(row["source_file_rechecked_this_run"] for row in report["supplemental_source_evidence"]))

    def test_current_fixture_matches_same_authoritative_baseline(self):
        self.assertTrue(gate.audit(self.root)["ok"])

    def test_changed_project_original_is_named(self):
        path = self.root / gate.PROJECT_DIR / "heroine_concept_LOCKED.png"
        path.write_bytes(path.read_bytes() + b"fixture corruption")
        self.issue(gate.audit(self.root), "CHANGED", path.name)

    def test_changed_package_original_is_named(self):
        path = self.root / gate.PACKAGE_DIR / "09_npc_chenyuan.jpeg"
        path.write_bytes(b"fixture corruption")
        self.issue(gate.audit(self.root), "CHANGED", path.name)

    def test_missing_project_original_is_named(self):
        (self.root / gate.PROJECT_DIR / "bus_stop_LOCKED.png").unlink()
        self.issue(gate.audit(self.root), "MISSING", "bus_stop_LOCKED.png")

    def test_missing_package_original_is_named(self):
        (self.root / gate.PACKAGE_DIR / "03_bus_stop.png").unlink()
        self.issue(gate.audit(self.root), "MISSING", "03_bus_stop.png")

    def test_renaming_preserves_count_but_still_fails(self):
        directory = self.root / gate.PROJECT_DIR
        (directory / "bus_stop_LOCKED.png").rename(directory / "unapproved.png")
        report = gate.audit(self.root)
        self.issue(report, "MISSING", "bus_stop_LOCKED.png")
        self.issue(report, "UNLISTED", "unapproved.png")

    def test_unlisted_nested_asset_is_detected(self):
        directory = self.root / gate.PACKAGE_DIR / "extra"
        directory.mkdir()
        (directory / "other.png").write_bytes(b"fixture")
        self.issue(gate.audit(self.root), "UNLISTED", "extra/other.png")

    def test_godot_sidecar_allowed_only_for_known_asset(self):
        directory = self.root / gate.PROJECT_DIR
        (directory / "bus_stop_LOCKED.png.import").write_text("fixture metadata", encoding="utf-8")
        self.assertTrue(gate.audit(self.root)["ok"])
        (directory / "unknown.png.import").write_text("not an escape hatch", encoding="utf-8")
        self.issue(gate.audit(self.root), "UNLISTED", "unknown.png.import")

    def test_missing_manifest_is_not_silently_ignored(self):
        (self.root / gate.PACKAGE_DIR / gate.MANIFEST_NAME).unlink()
        self.issue(gate.audit(self.root), "MISSING", gate.MANIFEST_NAME)

    def test_changing_both_image_and_manifest_cannot_bless_damage(self):
        image = self.root / gate.PACKAGE_DIR / "01_protagonist.png"
        image.write_bytes(b"changed image and claimed new baseline")
        manifest = self.root / gate.PACKAGE_DIR / gate.MANIFEST_NAME
        text = manifest.read_text(encoding="utf-8").replace(gate.PACKAGE_ASSETS[0][2], gate.sha256(image))
        manifest.write_text(text, encoding="utf-8")
        report = gate.audit(self.root)
        self.issue(report, "CHANGED", gate.MANIFEST_NAME)
        self.issue(report, "CHANGED", "01_protagonist.png")

    def test_duplicate_manifest_entry_is_invalid(self):
        path = self.root / gate.PACKAGE_DIR / gate.MANIFEST_NAME
        text = path.read_text(encoding="utf-8")
        path.write_text(text + "\n" + text.splitlines()[0], encoding="utf-8")
        self.issue(gate.audit(self.root), "INVALID_MANIFEST", "duplicate")

    def test_manifest_cannot_reference_outside_locked_folder(self):
        path = self.root / gate.PACKAGE_DIR / gate.MANIFEST_NAME
        path.write_text("0" * 64 + "  ../outside.png\n", encoding="utf-8")
        self.issue(gate.audit(self.root), "INVALID_MANIFEST", "malformed")

    def test_four_later_images_each_have_pinned_attachment_digest(self):
        for _, name, _ in gate.ATTACHMENT_ASSETS:
            with self.subTest(name=name):
                path = self.root / gate.PROJECT_DIR / name
                preserved = path.read_bytes()
                path.write_bytes(b"corrupt later attachment fixture")
                self.issue(gate.audit(self.root), "CHANGED", name)
                path.write_bytes(preserved)

    def test_missing_historical_attachment_evidence_is_unverified(self):
        name = gate.ATTACHMENT_ASSETS[0][0]
        self.edit_record(lambda data: data.update(active_locations=[row for row in data["active_locations"] if row["source_attachment"] != name]))
        self.issue(gate.audit(self.root), "UNVERIFIED_SOURCE", gate.ATTACHMENT_ASSETS[0][1])

    def test_changing_attachment_and_record_cannot_set_new_baseline(self):
        _, name, _ = gate.ATTACHMENT_ASSETS[0]
        path = self.root / gate.PROJECT_DIR / name
        path.write_bytes(b"fixture corruption")
        for field in ("files", "active_locations"):
            def edit(data, field=field):
                for row in data[field]:
                    if row["path"].endswith(name):
                        row["sha256" if field == "files" else "source_sha256"] = gate.sha256(path)
            self.edit_record(edit)
        self.issue(gate.audit(self.root), "CHANGED", name)

    def test_invalid_json_reports_source_problem_without_traceback(self):
        (self.root / gate.INTEGRITY_FILE).write_text("[broken", encoding="utf-8")
        self.issue(gate.audit(self.root), "UNVERIFIED_SOURCE", gate.INTEGRITY_FILE.as_posix())

    def test_explicit_external_fixture_comparison(self):
        sources = self.root / "external-fixture"
        sources.mkdir()
        for original, name, _ in gate.ATTACHMENT_ASSETS:
            shutil.copyfile(self.root / gate.PROJECT_DIR / name, sources / original)
        report = gate.audit(self.root, sources)
        self.assertTrue(report["ok"], report["issues"])
        self.assertTrue(all(row["source_file_rechecked_this_run"] for row in report["supplemental_source_evidence"]))
        # This verifies the optional API using copies, not actual user sources.
        (sources / gate.ATTACHMENT_ASSETS[0][0]).unlink()
        report = gate.audit(self.root, sources)
        self.issue(report, "MISSING", gate.ATTACHMENT_ASSETS[0][0])
        self.assertFalse(report["supplemental_source_evidence"][0]["source_file_rechecked_this_run"])

    def test_cli_exit_code_and_json_result(self):
        command = [sys.executable, str(CODE_ROOT / "tools/check_locked_assets.py"), "--root", str(self.root), "--json"]
        passed = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(0, passed.returncode, passed.stderr)
        self.assertTrue(json.loads(passed.stdout)["ok"])
        (self.root / gate.PROJECT_DIR / "lookout_LOCKED.png").unlink()
        failed = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(1, failed.returncode, failed.stderr)
        self.issue(json.loads(failed.stdout), "MISSING", "lookout_LOCKED.png")

    def test_street_psd_is_allowed_only_with_its_pinned_name_and_bytes(self):
        path = self.root / gate.STREET_ORIGINAL
        self.assertTrue(gate.audit(self.root)["ok"])
        path.rename(path.with_name("street_candidate.psd"))
        report = gate.audit(self.root)
        self.issue(report, "MISSING", path.name)
        self.issue(report, "UNLISTED", "street_candidate.psd")

    def test_street_original_and_changed_record_cannot_bless_damage(self):
        path = self.root / gate.STREET_ORIGINAL
        path.write_bytes(b"damaged PSD fixture")
        manifest = self.root / gate.STREET_MANIFEST
        record = json.loads(manifest.read_text(encoding="utf-8"))
        record["source"]["sha256"] = record["copy"]["sha256"] = gate.sha256(path)
        manifest.write_text(json.dumps(record), encoding="utf-8")
        report = gate.audit(self.root)
        self.issue(report, "CHANGED", path.name)
        self.issue(report, "UNVERIFIED_SOURCE", gate.STREET_MANIFEST.as_posix())

    def test_changed_embedded_display_copy_is_named(self):
        path = self.root / gate.STREET_PREVIEW
        path.write_bytes(b"not the saved composite")
        self.issue(gate.audit(self.root), "CHANGED", path.name)

    def test_missing_street_source_record_is_unverified(self):
        (self.root / gate.STREET_MANIFEST).unlink()
        self.issue(gate.audit(self.root), "UNVERIFIED_SOURCE", gate.STREET_MANIFEST.as_posix())

    def test_street_pixel_hash_and_no_recomposition_evidence_are_required(self):
        manifest = self.root / gate.STREET_MANIFEST
        original = manifest.read_text(encoding="utf-8")
        for group, key, value in [("preview", "pixel_sha256", "0" * 64),
                                  ("method", "recomposite", True),
                                  ("method", "color_conversion", True),
                                  ("method", "resize", True)]:
            with self.subTest(field=f"{group}.{key}"):
                record = json.loads(original)
                record[group][key] = value
                manifest.write_text(json.dumps(record), encoding="utf-8")
                self.issue(gate.audit(self.root), "UNVERIFIED_SOURCE", f"{group}.{key}")

    def test_optional_street_source_comparison_does_not_claim_live_access_by_default(self):
        default = gate.audit(self.root)
        self.assertFalse(default["street_source_evidence"]["source_file_rechecked_this_run"])
        # The optional source is explicitly a fixture copy, never a user's file.
        report = gate.audit(self.root, street_source=self.root / gate.STREET_ORIGINAL)
        self.assertTrue(report["ok"], report["issues"])
        self.assertTrue(report["street_source_evidence"]["source_file_rechecked_this_run"])
        missing = gate.audit(self.root, street_source=self.root / "missing-source.psd")
        self.issue(missing, "MISSING", "missing-source.psd")

    def test_importer_refuses_wrong_source_before_loading_optional_libraries(self):
        source = self.root / "incorrect-source.psd"
        source.write_bytes(b"not the user attachment")
        before = gate.sha256(self.root / gate.STREET_ORIGINAL)
        with self.assertRaisesRegex(ValueError, "CHANGED: source attachment"):
            street_import.import_background(source, self.root)
        self.assertEqual(before, gate.sha256(self.root / gate.STREET_ORIGINAL))

    def test_importer_never_overwrites_different_preserved_bytes(self):
        path = self.root / "isolated-preservation-fixture.bin"
        self.assertEqual("created", street_import.preserve_file(path, b"original"))
        self.assertEqual("already_identical", street_import.preserve_file(path, b"original"))
        with self.assertRaisesRegex(ValueError, "refusing to overwrite"):
            street_import.preserve_file(path, b"edited")
        self.assertEqual(b"original", path.read_bytes())

    def test_importer_missing_saved_preview_never_falls_back_to_layers(self):
        class NoPreview:
            def has_preview(self): return False
            def topil(self, **kwargs): raise AssertionError("must not decode unavailable preview")
            def composite(self, **kwargs): raise AssertionError("must never recompose")
        with self.assertRaisesRegex(ValueError, "MISSING_EMBEDDED_PREVIEW"):
            street_import.embedded_preview(NoPreview())

    def test_importer_explicitly_disables_icc_and_rejects_empty_saved_preview(self):
        calls = []
        class EmptyPreview:
            def has_preview(self): return True
            def topil(self, **kwargs): calls.append(kwargs); return None
            def composite(self, **kwargs): raise AssertionError("must never recompose")
        with self.assertRaisesRegex(ValueError, "MISSING_EMBEDDED_PREVIEW"):
            street_import.embedded_preview(EmptyPreview())
        self.assertEqual([{"apply_icc": False}], calls)


if __name__ == "__main__":
    unittest.main()
