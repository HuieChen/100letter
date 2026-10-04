"""Check retained review artifact bytes; this does not approve game usability."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    items = []
    for folder, reviews in (
        ("tabs-guide_20261004", "core-book-20261004"),
        ("corner-review_20261004", "core-book-corner-20261004"),
    ):
        evidence = json.loads((ROOT / "docs/testing" / folder / "book-evidence.json").read_text(encoding="utf-8"))
        items += evidence["automated_screenshots"] + [evidence["engine"]["result"], evidence["engine"]["log"]]
        records = ROOT / "production/qa/reviews" / reviews
        for record in sorted(records.glob("*.json")):
            if record.name != "finish.json":
                items += json.loads(record.read_text(encoding="utf-8"))["artifacts"]
    followup = json.loads((ROOT / "docs/testing/corner-review_20261004/native-followup.json").read_text(encoding="utf-8"))
    items += followup["artifacts"]
    tactile = json.loads((ROOT / "docs/testing/tactile-mail_20261004/evidence.json").read_text(encoding="utf-8"))
    items += tactile["artifacts"]
    native_path = ROOT / "docs/testing/tactile-mail_20261004/native.json"
    if native_path.exists():
        items += json.loads(native_path.read_text(encoding="utf-8"))["artifacts"]
    pastel = ROOT / "docs/testing/pastel-global_20261004/evidence.json"
    if pastel.exists():
        items += json.loads(pastel.read_text(encoding="utf-8"))["artifacts"]
    pastel_native = ROOT / "docs/testing/pastel-global_20261004/native.json"
    if pastel_native.exists():
        items += json.loads(pastel_native.read_text(encoding="utf-8"))["artifacts"]
    observed = {}
    for item in items:
        path = (ROOT / item["path"]).resolve()
        path.relative_to(ROOT)  # Reject references outside this checkout.
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != item["sha256"]:
            raise ValueError("Retained artifact bytes differ: " + item["path"])
        observed[item["path"]] = digest
    print(f"{len(observed)} retained artifacts match exact hashes; gameplay acceptance remains separate")


if __name__ == "__main__":
    main()
