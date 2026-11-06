"""Stage Godot's selected-resource ZIP plus exact, explicit raw dependencies."""
from pathlib import Path, PurePosixPath
import argparse
import fnmatch
import hashlib
import json
import re
import shutil
import zipfile

FORBIDDEN = re.compile(
    r'^(work|artifacts|specification|docs|tools|tests|test-results|local-data|builds)/'
    r'|^assets/(locked_user|generated|characters|reference_gate)/'
    r'|^scripts/reference_gate/|^scripts/(main\.gd|core/|rebuild/(post_office_room|title_screen)\.gd)'
    r'|^scenes/(main|reference_fidelity_prototype)\.tscn|^data/game\.json$'
    r'|\.(psd|mp4|mkv|exe|pck|zip)$', re.I)
COVER = 'assets/display_user/dear_somewhere_cover_USER_20261024.png'


def safe_path(name, exclusions=()):
    name = name.removeprefix('res://').replace('\\', '/')
    if (not name or name.startswith('/') or ':' in name
            or any(part in ('', '.', '..') for part in name.split('/'))
            or FORBIDDEN.search(name)
            or (name.startswith('assets/display_user/') and name not in
                (COVER, COVER + '.import', COVER + '.remap'))
            or any(fnmatch.fnmatchcase(name, pattern) for pattern in exclusions)):
        raise ValueError('Unsafe or excluded runtime path: ' + name)
    return PurePosixPath(name).as_posix()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def complete(repo, archive, stage, manifest):
    repo = repo.resolve()
    if stage.exists() and any(stage.iterdir()):
        raise ValueError('Use a fresh staging directory; preserve prior build evidence.')
    stage.mkdir(parents=True, exist_ok=True)
    preset = (repo / 'export_presets.cfg').read_text(encoding='utf-8-sig')
    filters = {}
    for key in ('include_filter', 'exclude_filter'):
        matches = re.findall(r'^' + key + r'="([^"]*)"$', preset, re.M)
        if len(matches) != 1:
            raise ValueError('Expected exactly one ' + key)
        filters[key] = [x.strip() for x in matches[0].split(',') if x.strip()]
    entries = {}

    def destination(name):
        name = safe_path(name, filters['exclude_filter'])
        dest = stage / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        return name, dest

    def record(name, dest, origin):
        entries[name] = dict(path='res://' + name, source=str(dest.resolve()),
                             sha256=sha(dest), origin=origin)

    with zipfile.ZipFile(archive) as zipped:
        for info in zipped.infolist():
            if info.is_dir():
                continue
            name, dest = destination(info.filename)
            if name in entries:
                raise ValueError('Duplicate exported path: ' + name)
            with zipped.open(info) as src, dest.open('wb') as dst:
                shutil.copyfileobj(src, dst)
            record(name, dest, 'selected-resource-export')
    exported = len(entries)
    raw = {}
    for pattern in filters['include_filter']:
        safe_path(pattern, filters['exclude_filter'])
        matches = sorted(p for p in repo.glob(pattern) if p.is_file())
        if not matches and not any(c in pattern for c in '*?['):
            raise ValueError('Missing explicit raw dependency: ' + pattern)
        for src in matches:
            if not src.resolve().is_relative_to(repo):
                raise ValueError('Raw dependency escapes project: ' + pattern)
            name, dest = destination(src.relative_to(repo).as_posix())
            digest = sha(src)
            if name in entries and entries[name]['sha256'] != digest:
                raise ValueError('Export/raw content mismatch: ' + name)
            shutil.copy2(src, dest)
            record(name, dest, 'explicit-raw-source')
            raw['res://' + name] = digest
    result = dict(entries=[entries[key] for key in sorted(entries)],
                  total_entries=len(entries), exported_entries=exported,
                  raw_count=len(raw), raw_required=raw, zip_sha256=sha(archive))
    manifest.write_text(json.dumps(result, indent=2), encoding='utf-8')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ('repo', 'zip', 'stage', 'manifest'):
        parser.add_argument('--' + key, type=Path, required=True)
    args = parser.parse_args()
    result = complete(args.repo, args.zip, args.stage, args.manifest)
    print(f"RUNTIME_INVENTORY {result['total_entries']} entries; {result['raw_count']} raw files verified")
