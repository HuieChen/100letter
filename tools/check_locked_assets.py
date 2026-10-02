"""Read-only locked-art gate; Python standard library only.

Nine image digests come from the final production pack, not today's project
files. Four later attachments are anchored to the previously recorded source
digests in docs/ASSET_INTEGRITY.json and docs/ASSET_PROVENANCE.md. CI verifies
their preserved project bytes and provenance records, but does not claim to
have re-read the user's temporary attachments. Use --source-attachments DIR
for that separate, optional source-file comparison.
The later street PSD has its own independently compared source-byte anchor
and embedded-preview provenance record; its 13 earlier originals stay pinned.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

PACKAGE_DIR = Path("specification/final_production_v1/10_LOCKED_USER_ASSETS")
PROJECT_DIR = Path("assets/locked_user")
INTEGRITY_FILE = Path("docs/ASSET_INTEGRITY.json")
MANIFEST_NAME = "LOCKED_ASSET_HASHES.sha256"
STREET_MANIFEST = Path("docs/STREET_BACKGROUND_IMPORT.json")
STREET_ORIGINAL = PROJECT_DIR / "street_scenery_USER_20261001_LOCKED.psd"
STREET_PREVIEW = Path("assets/display_user/street_scenery_USER_20261001_LOCKED.png")
# Independently read from the user's 2026-10-01 attachment, then compared to
# the byte-identical locked copy and its author-saved RGB composite preview.
STREET_SOURCE_SHA256 = "a0d949f8da64c48982e885231cd67eb7af99ef3914373be0e6f20a6e85e39597"
STREET_SOURCE_BYTES = 75344324
STREET_PREVIEW_SHA256 = "2fe03fbfaa4ddcdce454904080f32b0c3318e4c5ab3b55945bafadeb0f1b82fb"
STREET_PIXEL_SHA256 = "d9a9d7de8b4f2d2faf0529a87c88b687dbcacfc8a0805c7d1752484f54d7d1ce"
STREET_SIZE = [9600, 1080]
# User-supplied package manifest; pinning prevents silently blessing an edited
# image simply by editing the companion manifest in the same change.
MANIFEST_SHA256 = "ce0ca473039382241f881f14814bafd82c526d1704fa4c627a07f49d089a2c6c"
PACKAGE_ASSETS = (
    ("01_protagonist.png", "heroine_concept_LOCKED.png", "e51b7f86cc994ea13421463d2601006a0552a6b4c2a88e8b42a211051c88a4d7"),
    ("02_chess_stall.png", "chess_stall_LOCKED.png", "8cbeae2f7ae6f3e18f26c0ea49bc5afec12e741f5ece1b2426b4ba4e2b1b446c"),
    ("03_bus_stop.png", "bus_stop_LOCKED.png", "8e69e0c923aa606877b0dcd4caa012859276c2e8bbfefc08c7fb915c9fe4b368"),
    ("04_tarot_shop.png", "tarot_shop_LOCKED.png", "4fb721b82bfa6f245fb23e82ff5e91caaf5b69fdcb30372e1118b70fcd0dfbf6"),
    ("05_lookout.png", "lookout_LOCKED.png", "51036f2afc2d31526a194c4dfe1113c877f36c3e6177f3fa3e9fba023e1a67d1"),
    ("06_residential.jpeg", "residential_building_LOCKED.jpeg", "cd7a321d4c44452c2a24458428eb38abfbac693ccd6e66d4607e0cd1381407ae"),
    ("07_post_office.jpeg", "post_office_exterior_LOCKED.jpeg", "c5a2f98fc5636a57e75e61b638dbc9f0f376e2946cc82c53136a853532d64340"),
    ("08_community_center.jpeg", "community_center_LOCKED.jpeg", "836dffc899d13e08bffc8b2a2bef606bd544da80736b9e3e77ebe068e229864c"),
    ("09_npc_chenyuan.jpeg", "npc_chenyuan_LOCKED.jpeg", "b7ced62b1783ea3ef7666b3c6fb235526a19d5d23996620161ef192c2bc35427"),
)
# These are recorded ATTACHMENT digests, not a fresh baseline of project files.
ATTACHMENT_ASSETS = (
    ("28709a623c6f1d42dc3415214a77efd8.png", "chess_stall_USER_20261001_LOCKED.png", "61b38e2880dbc096cb9d3b8e05c45978f020e2ee04c33247c3422722cb36aa00"),
    ("bad5c6a2291fee65ec834987d3c51e4b.png", "residential_building_USER_20261001_LOCKED.png", "2e918363c006372d9a28ba508b5479f0f466084cc26e9b2de7f432013465efb0"),
    ("abd5853cb2c889d0f1a4411324f0edd7.jpg", "post_office_exterior_USER_20261001_LOCKED.jpg", "10505e65f9ff2beb0bfec42d7492c169a2257582f7b6218711bf1824f2d69d5b"),
    ("af4b7dabac593b5bf81d2ec9260a6ab2.jpg", "community_center_USER_20261001_LOCKED.jpg", "df908fd63a384cc81a8bf9344368a1814ac5250b13806f600e745159e9013873"),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def audit(root: Path, source_attachments: Path | None = None, street_source: Path | None = None) -> dict:
    root = root.resolve()
    issues: list[dict] = []
    checked: list[dict] = []

    def fail(code: str, path: str | Path, detail: str) -> None:
        issues.append({"code": code, "path": str(path).replace("\\", "/"), "detail": detail})

    def check_file(path: Path, expected: str, scope: str, absolute: bool = False) -> None:
        target = path if absolute else root / path
        row = {"path": path.as_posix(), "scope": scope, "expected_sha256": expected, "ok": False}
        checked.append(row)
        if target.is_symlink():
            fail("CHANGED", path, "symbolic link cannot stand in for a preserved original")
        elif not target.is_file():
            fail("MISSING", path, "expected regular file")
        else:
            try:
                row["actual_sha256"] = sha256(target)
                row["ok"] = row["actual_sha256"] == expected
                if not row["ok"]:
                    fail("CHANGED", path, f"expected {expected}; got {row['actual_sha256']}")
            except OSError as exc:
                fail("UNREADABLE", path, str(exc))

    def check_inventory(directory: Path, allowed: set[str]) -> None:
        target = root / directory
        if target.is_symlink():
            fail("CHANGED", directory, "locked directory must not be a symbolic link")
        if not target.is_dir():
            fail("MISSING", directory, "locked directory missing")
            return
        for path in sorted(target.rglob("*")):
            if path.is_dir() and not path.is_symlink():
                continue
            name = path.relative_to(target).as_posix()
            # Only matching Godot import sidecars are permitted. An arbitrary
            # unknown file cannot evade the inventory by adding '.import'.
            if name in allowed or (name.endswith(".import") and name[:-7] in allowed):
                continue
            fail("UNLISTED", directory / name, "file not present in the approved inventory")

    package_names = {row[0] for row in PACKAGE_ASSETS}
    project_hashes = {str(PROJECT_DIR / name).replace("\\", "/"): digest
                      for _, name, digest in PACKAGE_ASSETS + ATTACHMENT_ASSETS}
    check_inventory(PACKAGE_DIR, package_names | {MANIFEST_NAME, "README_LOCKED.md"})
    check_inventory(PROJECT_DIR, {row[1] for row in PACKAGE_ASSETS + ATTACHMENT_ASSETS} | {STREET_ORIGINAL.name})
    manifest_path = PACKAGE_DIR / MANIFEST_NAME
    check_file(manifest_path, MANIFEST_SHA256, "package_manifest")
    if (root / manifest_path).is_file():
        try:
            parsed: dict[str, str] = {}
            for number, line in enumerate((root / manifest_path).read_text(encoding="utf-8").splitlines(), 1):
                if not line.strip():
                    continue
                match = re.fullmatch(r"([0-9a-fA-F]{64})  ([^/\\]+)", line)
                if not match:
                    fail("INVALID_MANIFEST", manifest_path, f"malformed line {number}")
                    continue
                digest, name = match.groups()
                if name in parsed:
                    fail("INVALID_MANIFEST", manifest_path, f"duplicate entry {name}")
                parsed[name] = digest.lower()
            for name in sorted(parsed.keys() - package_names):
                fail("UNLISTED", manifest_path, f"unapproved manifest entry {name}")
            for name, _, digest in PACKAGE_ASSETS:
                if name not in parsed:
                    fail("MISSING", manifest_path, f"manifest entry {name}")
                elif parsed[name] != digest:
                    fail("CHANGED", manifest_path, f"manifest digest for {name} disagrees with user package")
        except (OSError, UnicodeError) as exc:
            fail("INVALID_MANIFEST", manifest_path, str(exc))
    for package_name, project_name, digest in PACKAGE_ASSETS:
        check_file(PACKAGE_DIR / package_name, digest, "package_image")
        check_file(PROJECT_DIR / project_name, digest, "project_package_image")
    for _, project_name, digest in ATTACHMENT_ASSETS:
        check_file(PROJECT_DIR / project_name, digest, "project_attachment_image")

    provenance: dict = {}
    try:
        provenance = json.loads((root / INTEGRITY_FILE).read_text(encoding="utf-8"))
        if not isinstance(provenance, dict):
            raise ValueError("expected an object")
    except (OSError, UnicodeError, ValueError) as exc:
        fail("UNVERIFIED_SOURCE", INTEGRITY_FILE, f"cannot read historical source evidence: {exc}")
        provenance = {}
    records: dict[str, dict] = {}
    for row in provenance.get("files", []) if isinstance(provenance.get("files"), list) else []:
        if not isinstance(row, dict) or not isinstance(row.get("path"), str):
            fail("UNVERIFIED_SOURCE", INTEGRITY_FILE, "malformed file record")
            continue
        name = row["path"]
        if name in records:
            fail("UNVERIFIED_SOURCE", INTEGRITY_FILE, f"duplicate file record {name}")
        records[name] = row
        if name not in project_hashes:
            fail("UNLISTED", INTEGRITY_FILE, f"unapproved file record {name}")
        elif row.get("sha256") != project_hashes[name]:
            fail("CHANGED", INTEGRITY_FILE, f"recorded digest changed for {name}")
    for name in sorted(project_hashes.keys() - records.keys()):
        fail("UNVERIFIED_SOURCE", INTEGRITY_FILE, f"missing file record {name}")
    active = provenance.get("active_locations", [])
    active = active if isinstance(active, list) else []
    sources: list[dict] = []
    for original_name, project_name, digest in ATTACHMENT_ASSETS:
        relative = (PROJECT_DIR / project_name).as_posix()
        candidates = [row for row in active if isinstance(row, dict) and row.get("path") == relative]
        source_ok = (
            len(candidates) == 1
            and candidates[0].get("source_attachment") == original_name
            and candidates[0].get("source_sha256") == digest
            and candidates[0].get("verified_byte_identical") is True
            and records.get(relative, {}).get("origin") == "user_attachment_2026-10-01"
        )
        if not source_ok:
            fail("UNVERIFIED_SOURCE", relative, "attachment name/digest/origin/previous source comparison missing or inconsistent")
        source = {"attachment": original_name, "project_path": relative,
                  "historical_source_record_verified": source_ok,
                  "source_file_rechecked_this_run": False}
        if source_attachments is not None:
            before = len(issues)
            check_file(source_attachments.resolve() / original_name, digest, "external_attachment", absolute=True)
            source["source_file_rechecked_this_run"] = len(issues) == before
        sources.append(source)
    check_file(STREET_ORIGINAL, STREET_SOURCE_SHA256, "project_street_original")
    check_file(STREET_PREVIEW, STREET_PREVIEW_SHA256, "street_embedded_preview")
    street_record_ok = False
    try:
        record = json.loads((root / STREET_MANIFEST).read_text(encoding="utf-8"))
        expected_fields = {
            ("source", "filename"): "街道景色.psd",
            ("source", "sha256"): STREET_SOURCE_SHA256,
            ("source", "size_bytes"): STREET_SOURCE_BYTES,
            ("source", "size"): STREET_SIZE,
            ("source", "mode"): "RGB",
            ("source", "depth"): 8,
            ("source", "has_embedded_preview"): True,
            ("copy", "path"): STREET_ORIGINAL.as_posix(),
            ("copy", "sha256"): STREET_SOURCE_SHA256,
            ("preview", "path"): STREET_PREVIEW.as_posix(),
            ("preview", "sha256"): STREET_PREVIEW_SHA256,
            ("preview", "pixel_sha256"): STREET_PIXEL_SHA256,
            ("preview", "size"): STREET_SIZE,
            ("preview", "mode"): "RGB",
            ("method", "export"): "PSDImage.topil(apply_icc=False)",
            ("method", "recomposite"): False,
            ("method", "color_conversion"): False,
            ("method", "resize"): False,
            ("method", "crop"): False,
            ("method", "ai_input"): False,
        }
        mismatches = [".".join(keys) for keys, expected in expected_fields.items()
                      if not isinstance(record, dict) or not isinstance(record.get(keys[0]), dict)
                      or record[keys[0]].get(keys[1]) != expected]
        street_record_ok = isinstance(record, dict) and record.get("schema_version") == 1 and not mismatches
        if not street_record_ok:
            fail("UNVERIFIED_SOURCE", STREET_MANIFEST, "street import evidence mismatch: " + ", ".join(mismatches))
    except (OSError, UnicodeError, ValueError) as exc:
        fail("UNVERIFIED_SOURCE", STREET_MANIFEST, f"cannot read street attachment provenance: {exc}")
    street_evidence = {"source_anchor_verified": street_record_ok, "source_file_rechecked_this_run": False,
                       "preview_pixels_redecoded_this_run": False,
                       "note": "CI pins the PNG bytes previously compared to the embedded RGB pixels; no PSD/Pillow dependency or layer recomposition is used by this gate."}
    if street_source is not None:
        before = len(issues)
        check_file(street_source.resolve(), STREET_SOURCE_SHA256, "external_street_attachment", absolute=True)
        street_evidence["source_file_rechecked_this_run"] = len(issues) == before
    return {
        "schema_version": 2,
        "ok": not issues,
        "checks": checked,
        "supplemental_source_evidence": sources,
        "street_source_evidence": street_evidence,
        "issues": issues,
        "note": "Default CI checks preserved originals and the pinned street saved-preview PNG against source anchors. It does not re-read external attachments, decode PSD pixels, recompose layers, or judge visual appearance.",
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--source-attachments", type=Path, help="optional folder containing the four original attachment filenames")
    parser.add_argument("--street-source", type=Path, help="optional original 街道景色.psd attachment for an independent source-byte comparison")
    parser.add_argument("--json", action="store_true", help="print machine-readable results; never write assets")
    args = parser.parse_args(argv)
    report = audit(args.root, args.source_attachments, args.street_source)
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        for issue in report["issues"]:
            print(f"{issue['code']}: {issue['path']}: {issue['detail']}")
        protected = [row for row in report["checks"] if row["scope"] != "package_manifest"]
        print(f"LOCKED_ASSETS {'PASS' if report['ok'] else 'FAIL'}: {sum(row['ok'] for row in protected)}/{len(protected)} asset checks; {len(report['issues'])} issue(s)")
        rechecked = sum(row["source_file_rechecked_this_run"] for row in report["supplemental_source_evidence"])
        print(f"Later attachments: historical source evidence checked; external source files rechecked this run: {rechecked}/4.")
        print(f"Street PSD: original + saved composite PNG pinned; external source rechecked: {report['street_source_evidence']['source_file_rechecked_this_run']}.")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
