"""Run pinned GUT with fresh JUnit proof and isolated user data, without plugins."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent


def verify_vendor() -> dict:
    lock = json.loads((ROOT / "tools/gut.lock.json").read_text(encoding="utf-8"))
    for item in lock["files"]:
        path = ROOT / item["path"]
        if hashlib.sha256(path.read_bytes()).hexdigest() != item["sha256"]:
            raise ValueError(f"Pinned GUT bytes differ: {item['path']}")
    if len(lock["files"]) != 259 or lock["version"] != "9.7.1":
        raise ValueError("Unexpected GUT version or incomplete snapshot")
    return lock


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    lock = verify_vendor()
    if args.verify_only:
        print(f"GUT {lock['version']}: 259 upstream files match pinned hashes")
        return 0
    if not args.godot or not args.godot.is_file():
        parser.error("Supply the real Godot 4.7.x executable with --godot")
    if not re.search(r"^4\.7\.", subprocess.check_output([str(args.godot), "--version"], text=True).strip()):
        raise ValueError("GUT 9.7.1 requires the reviewed Godot 4.7.x runtime")
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    out = ROOT / "test-results" / "gut" / stamp
    out.mkdir(parents=True)
    env = dict(os.environ, APPDATA=str(out / "AppData/Roaming"), LOCALAPPDATA=str(out / "AppData/Local"))
    for key in ("APPDATA", "LOCALAPPDATA"):
        Path(env[key]).mkdir(parents=True)
    args_base = [str(args.godot), "--headless", "--path", str(ROOT)]
    commands = [args_base + ["--editor", "--import", "--quit"], args_base + [
        "--script", "res://addons/gut/gut_cmdln.gd", "-gdir=res://qa/gut", "-gexit", "-gconfig=",
        "-gdisable_colors", "-gjunit_xml_file=" + str(out / "junit.xml")]]
    for name, command in zip(("import", "gut"), commands):
        result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, timeout=240)
        combined = result.stdout + result.stderr
        (out / (name + ".log")).write_bytes(combined)
        if result.returncode or b"ERROR:" in combined:
            raise ValueError(f"{name} failed; retained logs: {out}")
    reports = list(out.glob("junit*.xml"))
    if len(reports) != 1:
        raise ValueError(f"Expected one fresh GUT report, found {len(reports)}; {out}")
    report = ET.parse(reports[0]).getroot()  # Missing fresh report is failure, even with exit code 0.
    cases = list(report.iter("testcase"))
    failures = list(report.iter("failure")) + list(report.iter("error"))
    skipped = list(report.iter("skipped"))
    assertions = sum(int(case.get("assertions", "0")) for case in cases)
    if len(cases) < 8 or assertions < 580 or failures or skipped or any(case.get("status") != "pass" for case in cases):
        raise ValueError(f"Incomplete GUT proof: tests={len(cases)}, failures={len(failures)}, skipped={len(skipped)}; {out}")
    value = {"version": lock["version"], "upstream_revision": lock["revision"], "tests": len(cases), "assertions": assertions,
             "failures": len(failures), "skipped": len(skipped), "finished_utc": stamp, "commands": commands,
             "scope": "Production model guards, custody, privacy, tool cancellation and corrupt-save recovery; not native UI or player acceptance.",
             "junit_file": reports[0].name, "junit_sha256": hashlib.sha256(reports[0].read_bytes()).hexdigest()}
    (out / "result.json").write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(value, indent=2))
    print("Evidence: " + str(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
