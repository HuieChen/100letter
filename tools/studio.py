"""Project-local CCGS adapter. Runs existing Godot QA; never executes upstream hooks.

The gate validates evidence provenance/completeness, not artistic merit or human
satisfaction. A passing automated suite alone cannot close a player-facing chain.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import zlib
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_digest(path: Path) -> str:
    """Source fingerprints survive Git's CRLF/LF checkout normalization.

    Retained evidence still uses digest(): an artifact must match its exact bytes.
    Only the normal CRLF checkout pair is normalized, not content or whitespace.
    """
    content = path.read_bytes()
    if path.suffix.lower() in (".gd", ".tscn", ".json", ".md", ".py", ".yaml", ".godot", ".cfg"):
        content = content.replace(b"\r\n", b"\n")
    return hashlib.sha256(content).hexdigest()


def within(root: Path, relative: str) -> Path:
    if not isinstance(relative, str) or not relative or "\\" in relative:
        raise ValueError("Expected a nonempty forward-slash relative path")
    parts = relative.split("/")
    if any(p in ("", ".", "..") for p in parts) or Path(relative).is_absolute():
        raise ValueError(f"Unsafe project path: {relative}")
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f"Path leaves project: {relative}")
    return path


def fingerprint(root: Path) -> dict[str, str]:
    """Current runtime/test inputs; generated import/cache files are excluded."""
    paths = [root / "project.godot", root / "export_presets.cfg"]
    for directory in ("scripts", "scenes", "data", "tests", "assets/faefever_v2", "assets/fonts", "assets/generated", "assets/characters/generated", "assets/audio"):
        paths += [p for p in (root / directory).rglob("*") if p.is_file()
                  and p.suffix.lower() in (".gd", ".tscn", ".json", ".png", ".ttf", ".wav", ".ogg")]
    return {p.relative_to(root).as_posix(): source_digest(p) for p in sorted(set(paths)) if p.is_file()}


def verify(root: Path) -> dict:
    lock = read_json(root / "tools/studio/upstream.lock.json")
    config = read_json(root / "tools/studio/config.json")
    if lock.get("license") != "MIT" or not re.fullmatch(r"[0-9a-f]{40}", lock.get("revision", "")):
        raise ValueError("Missing MIT license or immutable upstream revision")
    if lock.get("hooks_activated") is not False or config.get("review_mode") != "solo_sequential":
        raise ValueError("Unexpected active hooks or implicit delegation")
    vendor = within(root, lock["vendor_root"])
    actual = {p.relative_to(vendor).as_posix() for p in vendor.rglob("*") if p.is_file()}
    if actual != set(lock["files"]):
        raise ValueError("Upstream snapshot inventory changed")
    for name, expected in lock["files"].items():
        if digest(within(vendor, name)) != expected:
            raise ValueError(f"Upstream bytes changed: {name}")
    agents = list((vendor / ".claude/agents").glob("*.md"))
    skills = list((vendor / ".claude/skills").glob("*/SKILL.md"))
    if len(agents) != lock["agent_count"] or len(agents) != 49 or len(skills) != lock["skill_count"]:
        raise ValueError("Upstream role/skill inventory does not match pin")
    if not config["required_native_checks"] or len(set(config["required_native_checks"])) != len(config["required_native_checks"]):
        raise ValueError("Native criteria must be nonempty and unique")
    for chain in config["chains"].values():
        for role in chain["roles"]:
            if not (vendor / ".claude/agents" / (role + ".md")).is_file():
                raise ValueError(f"Unknown role: {role}")
        if "suite" in chain:
            if not within(root, chain["suite"]).is_file():
                raise ValueError(f"Missing suite: {chain['suite']}")
            within(root, chain["suite_report"])
    return {"status": "ADAPTER_VERIFIED", "revision": lock["revision"], "agents": len(agents),
            "skills": len(skills), "vendored_files": len(actual), "game_acceptance": "NOT_ASSESSED"}


def brief(root: Path, chain_id: str) -> dict:
    verify(root)
    config = read_json(root / "tools/studio/config.json")
    chain = config["chains"][chain_id]
    return {"chain": chain_id, **chain, "mode": config["review_mode"],
            "source_documents": ["CURRENT_SPEC.md", "LATEST_USER_FEEDBACK.md", "TASK_QUEUE.md", "QA_GATES.md", "LOCKED_ASSETS.md"],
            "role_sources": [f"third_party/claude-code-game-studios/.claude/agents/{role}.md" for role in chain["roles"]],
            "native_checks_required": config["required_native_checks"],
            "completion_rule": "One complete state chain; current source + automated evidence + actual OS-input/visual review. No silent waiver; no implied player approval."}


def artifact(root: Path, item: dict) -> Path:
    path = within(root, item["path"])
    if not path.is_file() or digest(path) != item.get("sha256"):
        raise ValueError(f"Missing or changed evidence: {item['path']}")
    return path


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as stream:
        if stream.read(8) != b"\x89PNG\r\n\x1a\n":
            raise ValueError("Expected a retained PNG screenshot")
        dimensions = None
        image_data = False
        while True:
            prefix = stream.read(8)
            if len(prefix) != 8:
                raise ValueError("Truncated PNG evidence")
            length, kind = struct.unpack(">I4s", prefix)
            if length > 64 * 1024 * 1024:
                raise ValueError("Oversized PNG chunk")
            data = stream.read(length)
            checksum = stream.read(4)
            if len(data) != length or len(checksum) != 4 or zlib.crc32(kind + data) != struct.unpack(">I", checksum)[0]:
                raise ValueError("Invalid PNG chunk checksum")
            if dimensions is None:
                if kind != b"IHDR" or length != 13:
                    raise ValueError("Missing PNG header")
                dimensions = struct.unpack(">II", data[:8])
            if kind == b"IDAT" and length:
                image_data = True
            if kind == b"IEND":
                if length or not image_data or stream.read(1):
                    raise ValueError("Invalid PNG end or missing pixels")
                return dimensions


def gate(root: Path, chain_id: str, report: dict) -> dict:
    config = read_json(root / "tools/studio/config.json")
    problems: list[str] = []
    if report.get("chain") != chain_id:
        problems.append("Evidence belongs to another chain")
    current = fingerprint(root)
    if not current or report.get("source_fingerprint") != current:
        problems.append("Source/test/art fingerprint is missing or stale")
    engine = report.get("engine", {})
    if engine.get("exit_code") != 0 or type(engine.get("checks")) is not int or engine["checks"] < 1 or engine.get("failures") != []:
        problems.append("No passing, nonempty automated engine result")
    try:
        raw = read_json(artifact(root, engine["result"]))
        artifact(root, engine["log"])
        chain = config["chains"][chain_id]
        expected_suite = chain.get("suite_name")
        if raw.get(chain.get("suite_key", "suite")) != expected_suite or raw.get("checks") != engine.get("checks") or raw.get("failures") != []:
            problems.append("Engine result does not match recorded summary/suite")
    except (KeyError, ValueError, OSError, json.JSONDecodeError) as error:
        problems.append(f"Engine artifacts unverifiable: {error}")
    if report.get("source_unchanged_during_run") is not True:
        problems.append("Run did not establish stable source inputs")
    native = report.get("native_review") or {}
    if native.get("method") != "os_input_visual_review" or not native.get("reviewer") or not native.get("observations"):
        problems.append("Actual OS-input/visual review not recorded")
    checks = native.get("checks", {})
    for criterion in config["required_native_checks"]:
        if checks.get(criterion) != "PASS":
            problems.append(f"Native check pending/failed: {criterion}")
    try:
        shots = native.get("screenshots", [])
        sizes = [png_size(artifact(root, shot)) for shot in shots]
        if (1920, 1080) not in sizes:
            problems.append("No verified full 1920x1080 native screenshot")
    except (KeyError, ValueError, OSError) as error:
        problems.append(f"Native screenshot unverifiable: {error}")
    if report.get("unresolved_blockers") != []:
        problems.append("Unresolved blocker list missing or nonempty")
    return {"chain": chain_id, "status": "READY_FOR_PHASE_REPORT" if not problems else "NOT_COMPLETE",
            "blockers": problems, "player_acceptance": "NOT_INFERRED",
            "scope": "Evidence integrity/completeness gate; manual observations must actually be performed."}


def run(root: Path, chain_id: str, godot: Path) -> Path:
    verify(root)
    config = read_json(root / "tools/studio/config.json")
    chain = config["chains"][chain_id]
    if "suite" not in chain:
        raise ValueError("No verified suite mapped yet; do not substitute an unrelated test")
    before = fingerprint(root)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    folder = root / "test-results/studio" / chain_id / stamp
    folder.mkdir(parents=True)
    env = os.environ.copy()
    env["APPDATA"] = str(folder / "AppData/Roaming")
    env["LOCALAPPDATA"] = str(folder / "AppData/Local")
    for key in ("APPDATA", "LOCALAPPDATA"):
        Path(env[key]).mkdir(parents=True)
    log = folder / "engine.log"
    result_path = within(root, chain["suite_report"])
    prior_time = result_path.stat().st_mtime_ns if result_path.exists() else None
    args = [str(godot.resolve()), "--path", str(root), "--rendering-driver", "opengl3",
            "--position=-12000,-12000", "--audio-driver", "Dummy", "--resolution", "1920x1080",
            "--script", "res://" + chain["suite"], "--log-file", str(log), *chain.get("suite_args", [])]
    startup = None
    if os.name == "nt":
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
    import_args = [str(godot.resolve()), "--headless", "--path", str(root), "--editor", "--import", "--quit",
                   "--log-file", str(folder / "import.log")]
    imported = subprocess.run(import_args, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              startupinfo=startup, timeout=90)
    (folder / "import-output.txt").write_bytes(imported.stdout)
    if imported.returncode:
        raise ValueError(f"Fresh checkout import failed; inspect {folder / 'import.log'}")
    completed = subprocess.run(args, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               startupinfo=startup, timeout=90)
    (folder / "process-output.txt").write_bytes(completed.stdout)
    fresh = result_path.exists() and result_path.stat().st_mtime_ns != prior_time
    raw = read_json(result_path) if fresh else {}
    copied_result = folder / "engine-result.json"
    copied_result.write_text(json.dumps(raw, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    captures = []
    for original in raw.get("screenshots", []):
        src = within(root, original.removeprefix("res://"))
        dst = folder / src.name
        shutil.copy2(src, dst)
        captures.append({"path": dst.relative_to(root).as_posix(), "sha256": digest(dst)})
    report = {"schema_version": 1, "chain": chain_id, "captured_at_utc": stamp,
              "source_fingerprint": before, "source_unchanged_during_run": before == fingerprint(root),
              "engine": {"import_command": import_args, "command": args, "exit_code": completed.returncode,
                         "checks": raw.get("checks", 0), "failures": raw.get("failures", ["no fresh result"]),
                         "result": {"path": copied_result.relative_to(root).as_posix(), "sha256": digest(copied_result)},
                         "log": {"path": log.relative_to(root).as_posix(), "sha256": digest(log)}},
              "automated_screenshots": captures, "native_review": None,
              "unresolved_blockers": ["Native OS-input review, focus-loss, bilingual and full responsive checks pending"],
              "scope": "Scripted GPU input/rendering with Dummy audio; not native input, listening, novice timing or player approval"}
    if not report["source_unchanged_during_run"]:
        report["unresolved_blockers"].append("Source changed during run")
    out = folder / "evidence.json"
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if completed.returncode or not fresh or raw.get("failures") != [] or type(raw.get("checks")) is not int or raw["checks"] < 1:
        raise ValueError(f"Engine suite failed or did not produce fresh evidence; inspect {folder}")
    return out


def main() -> int:
    # PowerShell pipelines otherwise decode Windows' legacy Python code page as
    # UTF-8, corrupting Chinese criteria in the JSON shown to collaborators.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("verify", "roles", "brief", "run", "gate", "status", "ready", "dispatch", "finish", "handoff", "impact"))
    parser.add_argument("--chain", default="book")
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--review", action="append", default=[], help="Explicit project-relative review JSON; repeat per role")
    parser.add_argument("--path", action="append", default=[], help="Changed project-relative path for impact review")
    args = parser.parse_args()
    try:
        if args.action in ("status", "ready", "dispatch", "finish", "handoff", "impact"):
            spec = importlib.util.spec_from_file_location("studio_pipeline", ROOT / "tools/studio/pipeline.py")
            pipeline = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(pipeline)
            api = sys.modules[__name__]
            if args.action == "status":
                output = pipeline.status(ROOT, api)
            elif args.action == "ready":
                output = pipeline.ready(ROOT, args.chain, api)
            elif args.action == "dispatch":
                output = pipeline.dispatch(ROOT, args.chain, api)
            elif args.action in ("finish", "handoff"):
                output = getattr(pipeline, args.action)(ROOT, args.chain, args.evidence.as_posix() if args.evidence else None, args.review, api)
            else:
                if not args.path:
                    raise ValueError("Supply at least one --path for change propagation")
                output = pipeline.impact(ROOT, args.path, api)
        elif args.action == "verify":
            output = verify(ROOT)
        elif args.action == "roles":
            verify(ROOT)
            lock = read_json(ROOT / "tools/studio/upstream.lock.json")
            output = {"available_role_definitions": [p.stem for p in sorted((ROOT / lock["vendor_root"] / ".claude/agents").glob("*.md"))], "running_agents": "Not implied by role availability"}
        elif args.action == "brief":
            output = brief(ROOT, args.chain)
        elif args.action == "run":
            if not args.godot or not args.godot.is_file():
                raise ValueError("Provide --godot pointing to the installed Godot executable")
            evidence = run(ROOT, args.chain, args.godot)
            output = {"evidence": str(evidence), "engine": "PASS", "chain_completion": "PENDING_NATIVE_REVIEW"}
        else:
            verify(ROOT)
            if not args.evidence:
                raise ValueError("Provide a specific --evidence JSON; old results are not auto-selected")
            output = gate(ROOT, args.chain, read_json(args.evidence))
        print(json.dumps(output, ensure_ascii=False, indent=2))
        return 2 if output.get("status") == "NOT_COMPLETE" else 0
    except (ValueError, KeyError, OSError, subprocess.TimeoutExpired) as error:
        print(f"Studio adapter: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
