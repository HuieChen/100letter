"""Preserve the supplied PSD and export only its author-saved embedded preview.

Requires already available psd_tools and Pillow; never installs dependencies.
Existing originals/PNGs with different bytes are rejected, never overwritten.
There is no layer recomposition, ICC conversion, resizing, cropping or AI call.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import sys
from pathlib import Path

try:
    from . import check_locked_assets as gate
except ImportError:
    import check_locked_assets as gate

DEFAULT_SOURCE = Path("街道景色.psd")  # Supply --source for a private local archive.


def embedded_preview(document):
    """Never fall back to rendering layers when the saved preview is missing."""
    if not document.has_preview():
        raise ValueError("MISSING_EMBEDDED_PREVIEW: refusing to recompose PSD layers")
    image = document.topil(apply_icc=False)
    if image is None:
        raise ValueError("MISSING_EMBEDDED_PREVIEW: no author-saved pixels")
    if list(document.size) != gate.STREET_SIZE or document.depth != 8:
        raise ValueError("CHANGED: expected author PSD size 9600x1080 and 8-bit channels")
    if list(image.size) != gate.STREET_SIZE or image.mode != "RGB":
        raise ValueError("CHANGED: embedded preview must remain 9600x1080 RGB")
    if hashlib.sha256(image.tobytes()).hexdigest() != gate.STREET_PIXEL_SHA256:
        raise ValueError("CHANGED: embedded RGB pixels differ from the verified source anchor")
    return image


def preserve_file(path: Path, payload: bytes) -> str:
    """Create a new file exclusively or verify identical existing bytes."""
    if path.is_symlink():
        raise ValueError(f"CHANGED: refusing symbolic-link output {path}")
    if path.exists():
        if not path.is_file() or path.read_bytes() != payload:
            raise ValueError(f"CHANGED: refusing to overwrite preserved output {path}")
        return "already_identical"
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as stream:
        stream.write(payload)
        stream.flush()
        os.fsync(stream.fileno())
    return "created"


def import_background(source: Path, root: Path) -> dict:
    source = source.resolve()
    root = root.resolve()
    if source.is_symlink() or not source.is_file():
        raise ValueError(f"MISSING: expected regular source attachment {source}")
    if source.stat().st_size != gate.STREET_SOURCE_BYTES or gate.sha256(source) != gate.STREET_SOURCE_SHA256:
        raise ValueError("CHANGED: source attachment does not match verified 街道景色.psd bytes")
    # Source bytes and the protected outputs are validated before optional imports.
    for relative, digest in [(gate.STREET_ORIGINAL, gate.STREET_SOURCE_SHA256),
                             (gate.STREET_PREVIEW, gate.STREET_PREVIEW_SHA256)]:
        target = root / relative
        if target.is_symlink() or (target.exists() and (not target.is_file() or gate.sha256(target) != digest)):
            raise ValueError(f"CHANGED: refusing to overwrite {relative}")
        if not target.resolve().is_relative_to(root):
            raise ValueError(f"CHANGED: output escapes the project root: {relative}")
    import psd_tools
    import PIL
    from psd_tools import PSDImage
    from PIL import Image

    document = PSDImage.open(source)
    preview = embedded_preview(document)
    encoded = io.BytesIO()
    preview.save(encoded, format="PNG")
    payload = encoded.getvalue()
    if hashlib.sha256(payload).hexdigest() != gate.STREET_PREVIEW_SHA256:
        raise ValueError("CHANGED: PNG encoding differs from the pinned lossless display copy; preserved outputs are untouched")
    before = {root / gate.PROJECT_DIR / name: gate.sha256(root / gate.PROJECT_DIR / name)
              for _, name, _ in gate.PACKAGE_ASSETS + gate.ATTACHMENT_ASSETS
              if (root / gate.PROJECT_DIR / name).is_file()}
    copy_action = preserve_file(root / gate.STREET_ORIGINAL, source.read_bytes())
    preview_action = preserve_file(root / gate.STREET_PREVIEW, payload)
    with Image.open(root / gate.STREET_PREVIEW) as reopened:
        if reopened.mode != preview.mode or reopened.size != preview.size or reopened.tobytes() != preview.tobytes():
            raise ValueError("CHANGED: saved PNG does not retain the embedded RGB pixels")
    if any(gate.sha256(path) != digest for path, digest in before.items()):
        raise ValueError("CHANGED: an earlier locked original changed during import")
    record = {
        "schema_version": 1,
        "authorization": "User requested the supplied street PSD be imported and used unchanged; no AI fusion or repainting.",
        "source": {"path": source.as_posix(), "filename": "街道景色.psd", "sha256": gate.sha256(source),
                   "size_bytes": source.stat().st_size, "size": list(document.size), "mode": preview.mode,
                   "depth": document.depth, "has_embedded_preview": True},
        "copy": {"path": gate.STREET_ORIGINAL.as_posix(), "sha256": gate.sha256(root / gate.STREET_ORIGINAL),
                 "size_bytes": (root / gate.STREET_ORIGINAL).stat().st_size},
        "preview": {"path": gate.STREET_PREVIEW.as_posix(), "sha256": gate.sha256(root / gate.STREET_PREVIEW),
                    "pixel_sha256": hashlib.sha256(preview.tobytes()).hexdigest(), "size": list(preview.size),
                    "mode": preview.mode, "pixel_hash_layout": "RGB, row-major, top-left origin, unconverted 8-bit channels"},
        "method": {"read": "psd_tools.PSDImage.open(source)", "export": "PSDImage.topil(apply_icc=False)",
                   "recomposite": False, "color_conversion": False, "resize": False, "crop": False, "ai_input": False},
        "libraries": {"psd_tools": psd_tools.__version__, "Pillow": PIL.__version__},
        "verification": {"source_read_and_compared_this_import": True, "preview_reopened_pixel_identical": True,
                         "existing_locked_originals_rechecked_unchanged": len(before)},
    }
    record_path = root / gate.STREET_MANIFEST
    if record_path.is_symlink() or not record_path.resolve().is_relative_to(root):
        raise ValueError("CHANGED: refusing unsafe provenance path")
    record_path.parent.mkdir(parents=True, exist_ok=True)
    record_path.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return {"ok": True, "copy": copy_action, "preview": preview_action, "record": gate.STREET_MANIFEST.as_posix()}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--dependency-path", type=Path, action="append", default=[],
                        help="optional existing Python site-packages directory; nothing is installed")
    args = parser.parse_args(argv)
    for path in args.dependency_path:
        if not path.is_dir():
            parser.error(f"dependency path does not exist: {path}")
        sys.path.insert(0, str(path.resolve()))
    try:
        print(json.dumps(import_background(args.source, args.root), ensure_ascii=False))
        return 0
    except (OSError, ValueError, ImportError) as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
