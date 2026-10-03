"""Local production coordination. Roles are responsibilities, not spawned agents.

Creates explicit handoff briefs and rejects missing/stale review evidence. Never
executes commands, hooks or agent instructions from the vendored template.
"""
from __future__ import annotations

from datetime import datetime, timezone
import fnmatch
import json
from pathlib import Path


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def state(root, api):
    api.verify(root)
    project = load(root / "project.yaml")  # JSON is also valid YAML; no new dependency.
    board = load(root / "production/studio-board.json")
    if project["engine"] != {"name": "Godot", "version": "4.7.2", "language": "GDScript", "source_root": "scripts/rebuild", "entry": "scenes/final_slice.tscn"}:
        raise ValueError("Studio config must preserve the established Godot entry/layout")
    if project["upstream_revision"] != load(root / "tools/studio/upstream.lock.json")["revision"]:
        raise ValueError("Project and pinned studio revision disagree")
    stories = {}
    for path in board["stories"]:
        story = load(api.within(root, path))
        if story["id"] in stories:
            raise ValueError("Duplicate story ID")
        story["path"] = path
        stories[story["id"]] = story
    if board["active_story"] not in stories:
        raise ValueError("Unknown active story")
    vendor = api.within(root, load(root / "tools/studio/upstream.lock.json")["vendor_root"])
    roles = {path.stem for path in (vendor / ".claude/agents").glob("*.md")}
    for role, department in project["departments"].items():
        if role not in roles or department["parent"] not in roles | {"user"}:
            raise ValueError("Invalid department or reporting parent")
    for story in stories.values():
        if story["state"] not in ("queued", "review", "complete"):
            raise ValueError("Unknown story state")
        if story["chain"] not in load(root / "tools/studio/config.json")["chains"]:
            raise ValueError("Unknown state chain")
        if story["owner"] not in roles or not set(story["reviews_required"]).issubset(roles):
            raise ValueError("Unknown story role")
        if story["owner"] in story["reviews_required"]:
            raise ValueError("Implementation owner cannot also supply its own review verdict")
        if not story["acceptance"] or len({a["id"] for a in story["acceptance"]}) != len(story["acceptance"]):
            raise ValueError("Acceptance criteria must be nonempty and unique")
        for criterion in story["acceptance"]:
            if not criterion["requirement"] or not criterion["check"]:
                raise ValueError("Every criterion needs a requirement and verification method")
        for name in story["inputs"] + story["files"]:
            if not api.within(root, name).is_file():
                raise ValueError("Missing story input: " + name)
        for dependency in story["depends_on"]:
            if dependency not in stories:
                raise ValueError("Unknown dependency")
    visiting, visited = set(), set()

    def visit(key):
        if key in visiting:
            raise ValueError("Cyclic story dependencies")
        if key in visited:
            return
        visiting.add(key)
        for dependency in stories[key]["depends_on"]:
            visit(dependency)
        visiting.remove(key)
        visited.add(key)

    for key in stories:
        visit(key)
    return project, board, stories


def select(stories, chain):
    matches = [s for s in stories.values() if s["chain"] == chain]
    if len(matches) != 1:
        raise ValueError("A chain must map to one production story")
    return matches[0]


def basis(root, story, api):
    paths = ["project.yaml", "production/studio-board.json", "tools/studio.py", "tools/studio/config.json",
             "tools/studio/upstream.lock.json", "tools/studio/pipeline.py", story["path"]]
    paths += story["inputs"] + story["files"]
    return {name: api.source_digest(api.within(root, name)) for name in sorted(set(paths))}


def dependency_problems(root, story, stories, api):
    problems = []
    for key in story["depends_on"]:
        done = stories[key].get("completion")
        if stories[key]["state"] != "complete" or not done:
            problems.append("Dependency not completed: " + key)
            continue
        try:
            result = load(api.artifact(root, done))
            if result.get("status") != "COMPLETE" or result.get("chain") != stories[key]["chain"]:
                problems.append("Invalid dependency completion: " + key)
            if result.get("source_fingerprint") != api.fingerprint(root):
                problems.append("Dependency runtime evidence is stale: " + key)
        except (KeyError, OSError, ValueError):
            problems.append("Unverifiable dependency completion: " + key)
    return problems


def ready(root, chain, api):
    project, board, stories = state(root, api)
    story = select(stories, chain)
    problems = dependency_problems(root, story, stories, api)
    if story["state"] == "complete":
        problems.append("Story is already complete; reopen explicitly before new work")
    if story["id"] != board["active_story"]:
        problems.append("Not the single active story; producer must record the handoff")
    for role in [story["owner"], *story["reviews_required"]]:
        if role not in project["departments"]:
            problems.append("No department boundary for " + role)
    return {"chain": chain, "story": story["id"], "status": "READY_FOR_WORK" if not problems else "NOT_COMPLETE",
            "blockers": problems, "acceptance": story["acceptance"],
            "execution": project["execution"], "completion_is_not_implied": True}


def status(root, api):
    project, board, stories = state(root, api)
    return {"phase": project["phase"], "active_story": board["active_story"],
            "execution": project["execution"], "spawned_agents": 0,
            "phases": project["phases"], "stories": [{"id": s["id"], "chain": s["chain"],
                "state": s["state"], "owner": s["owner"], "depends_on": s["depends_on"],
                "reviews": s["reviews_required"]} for s in stories.values()],
            "open_bugs": board["open_bugs"], "game_acceptance": "NOT_COMPLETE"}


def dispatch(root, chain, api):
    check = ready(root, chain, api)
    if check["status"] != "READY_FOR_WORK":
        return check
    project, _, stories = state(root, api)
    story = select(stories, chain)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    folder = root / "test-results/studio/jobs" / chain / stamp
    folder.mkdir(parents=True)
    roles = [story["owner"], *story["reviews_required"]]
    briefs = []
    for role in roles:
        department = project["departments"][role]
        role_path = "third_party/claude-code-game-studios/.claude/agents/" + role + ".md"
        text = "\n".join([
            "# " + story["id"] + " — " + role,
            "Execution: sequential responsibility pass; no subagent launched.",
            "Role technical reference: " + role_path,
            "Parent: " + department["parent"],
            "Task: " + department["task"],
            "Story: " + story["path"],
            "Read once: " + ", ".join(story["inputs"] + story["files"]),
            "Allowed implementation domains: " + ", ".join(department["write_domains"]),
            "Acceptance: " + "; ".join(a["id"] + ": " + a["check"] for a in story["acceptance"]),
            "Find failures; do not confirm quality from test counts. Show exact file/step/evidence and severity.",
            "Missing native input, listening, novice or reference evidence is NOT_ASSESSED, never PASS.",
            "Preserve accepted art, original saves and existing entry. No upstream permissions/models/hooks are active.",
            "Return record: role, chain, basis, observed, criterion_results {AC-id:{status,observed}}, artifacts [{path,sha256}], verdict, findings [{id,severity,step,owner}].",
            "Verdicts: PASS / REWORK / NOT_ASSESSED. Ownership conflicts go to the named parent; cross-domain changes to producer.",
            "Output within this job: " + role + "-review.json. Do not invent an independent reviewer identity.",
        ]) + "\n"
        path = folder / (role + "-brief.md")
        path.write_text(text, encoding="utf-8")
        briefs.append({"role": role, "brief": path.relative_to(root).as_posix(), "sha256": api.digest(path)})
    result = {"chain": chain, "story": story["id"], "status": "BRIEFS_CREATED", "spawned_agents": 0,
              "execution": project["execution"], "basis": basis(root, story, api), "briefs": briefs,
              "handoffs": {"design": "ux-designer -> implementation owner", "implementation": "owner -> reviewers",
                           "rework": "reviewer findings -> owner -> rerun affected checks",
                           "complete": "qa-lead evidence check -> producer recorded handoff"}}
    write(folder / "dispatch.json", result)
    return {**result, "dispatch_file": (folder / "dispatch.json").relative_to(root).as_posix()}


def finish(root, chain, evidence, reviews, api):
    project, _, stories = state(root, api)
    story = select(stories, chain)
    problems = ready(root, chain, api)["blockers"]
    current = basis(root, story, api)
    verdicts = {}
    required_criteria = {criterion["id"] for criterion in story["acceptance"]}
    covered = set()
    for name in reviews:
        record_path = api.within(root, name)
        record = load(record_path)
        role = record.get("role")
        if role in verdicts or role not in story["reviews_required"]:
            problems.append("Duplicate/unassigned review role: " + str(role))
            continue
        verdicts[role] = record.get("verdict")
        if record.get("chain") != chain or record.get("basis") != current:
            problems.append("Review belongs to wrong/stale input: " + role)
        if record.get("execution") != project["execution"] or not record.get("observed"):
            problems.append("Actual review method/observations missing: " + role)
        if record.get("verdict") != "PASS" or record.get("findings") != []:
            problems.append("Review pending/rework: " + role)
        if not record.get("artifacts"):
            problems.append("Review artifacts missing: " + role)
        criteria = record.get("criterion_results", {})
        for key, result in criteria.items():
            if key not in required_criteria or not result.get("observed") or result.get("status") != "PASS":
                problems.append("Acceptance criterion pending/unverifiable: " + str(key))
            else:
                covered.add(key)
        for item in record.get("artifacts", []):
            try:
                api.artifact(root, item)
            except (KeyError, ValueError, OSError):
                problems.append("Review evidence missing/changed: " + role)
    for role in story["reviews_required"]:
        if role not in verdicts:
            problems.append("Required role review missing: " + role)
    for criterion in sorted(required_criteria - covered):
        problems.append("Acceptance criterion not verified: " + criterion)
    if evidence is None:
        problems.append("No current engine/native evidence supplied")
    else:
        checked = api.gate(root, chain, load(api.within(root, evidence)))
        problems.extend(checked["blockers"])
    return {"chain": chain, "story": story["id"], "status": "READY_FOR_RECORDED_HANDOFF" if not problems else "NOT_COMPLETE",
            "blockers": problems, "reviews": verdicts, "basis": current,
            "state_was_changed": False, "player_acceptance": "NOT_INFERRED"}


def impact(root, paths, api):
    project, _, stories = state(root, api)
    affected = set()
    roles = set()
    for path in paths:
        api.within(root, path)
        for story in stories.values():
            if path in story["inputs"] + story["files"]:
                affected.add(story["id"])
                roles.update([story["owner"], *story["reviews_required"]])
        for role, department in project["departments"].items():
            if any(fnmatch.fnmatchcase(path, pattern) for pattern in department["write_domains"]):
                roles.add(role)
    return {"changed_paths": paths, "affected_stories": sorted(affected), "notify_roles": sorted(roles),
            "coordinator": "producer", "requires_recheck": bool(affected),
            "state_was_changed": False, "messages_sent": False}


def handoff(root, chain, evidence, reviews, api):
    """Only a successful finish check can change the active production story."""
    checked = finish(root, chain, evidence, reviews, api)
    if checked["status"] != "READY_FOR_RECORDED_HANDOFF":
        return checked
    _, board, stories = state(root, api)
    story = select(stories, chain)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    receipt_name = "production/qa/handoffs/" + story["id"] + "-" + stamp + ".json"
    receipt = {**checked, "status": "COMPLETE", "source_fingerprint": api.fingerprint(root),
               "evidence": {"path": evidence, "sha256": api.digest(api.within(root, evidence))},
               "review_records": [{"path": name, "sha256": api.digest(api.within(root, name))} for name in reviews],
               "coordinator": "producer", "created_at_utc": stamp}
    write(api.within(root, receipt_name), receipt)
    stored = load(api.within(root, story["path"]))
    stored["state"] = "complete"
    stored["completion"] = {"path": receipt_name, "sha256": api.digest(api.within(root, receipt_name))}
    write(api.within(root, story["path"]), stored)
    next_story = next((s for s in stories.values() if s["state"] != "complete" and s["id"] != story["id"]), None)
    # Keep the last active ID if every story is complete; that is not a release gate.
    board["active_story"] = next_story["id"] if next_story else story["id"]
    write(root / "production/studio-board.json", board)
    return {"status": "HANDOFF_RECORDED", "chain": chain, "receipt": receipt_name,
            "next_story": board["active_story"], "game_acceptance": "NOT_INFERRED"}
