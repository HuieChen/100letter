"""Refresh the selected-resource export from adopted runtime AI artwork only.
No download, model invocation, source art editing, or publication occurs here.
"""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'assets/faefever_v2/manifest.json'


def selection():
    catalog = json.loads(MANIFEST.read_text(encoding='utf-8-sig'))
    entries = catalog.get('assets', {})
    if not entries:
        raise ValueError('No adopted final artwork has been registered.')
    paths = {'res://scenes/final_slice.tscn',
             'res://scripts/rebuild/field_book.gd',
             'res://scripts/rebuild/field_observation.gd',
             'res://assets/fonts/SolmereSans.ttf',
             'res://assets/fonts/Caveat.ttf'}
    for key, entry in entries.items():
        if not isinstance(entry, dict) or entry.get('ai_generated') is not True:
            raise ValueError(f'{key}: no explicit generated-asset provenance')
        path = entry.get('path', '')
        if not path.startswith('res://assets/faefever_v2/') or '..' in Path(path[6:]).parts:
            raise ValueError(f'{key}: runtime artwork is outside the approved asset tree')
        local = ROOT / path[6:]
        if not local.is_file():
            raise ValueError(f'{key}: adopted asset is missing: {path}')
        paths.add(path)
    # Selected scene dependencies do not recursively include every GDScript preload.
    # Explicitly walk the runtime source closure, including dynamically mounted roots.
    pending = [path for path in paths if path.endswith(('.gd', '.tscn', '.tres'))]
    visited = set()
    while pending:
        resource = pending.pop()
        if resource in visited:
            continue
        visited.add(resource)
        local = ROOT / resource[6:]
        if not local.is_file():
            raise ValueError(f'Missing runtime source dependency: {resource}')
        source = local.read_text(encoding='utf-8-sig')
        for dependency in re.findall(r'res://[^"\s]+\.(?:gd|tscn|tres)', source):
            if dependency not in paths:
                paths.add(dependency)
                pending.append(dependency)
    # This directory contains licensed local playback clips, not reference media.
    for path in (ROOT / 'assets/audio').rglob('*'):
        if path.is_file() and path.suffix.lower() in {'.wav', '.ogg'}:
            paths.add('res://' + path.relative_to(ROOT).as_posix())
    return sorted(paths)


def main():
    paths = selection()
    preset = ROOT / 'export_presets.cfg'
    source = preset.read_text(encoding='utf-8-sig')
    line = 'export_files=PackedStringArray(' + ', '.join(json.dumps(x) for x in paths) + ')'
    source, count = re.subn(r'^export_files=.*$', lambda _: line, source, flags=re.M)
    if count != 1:
        raise ValueError('Expected exactly one export selection.')
    includes = 'data/rebuild/*.json,assets/faefever_v2/manifest.json,assets/faefever_v2/characters/courier_walk_regions.json,assets/fonts/OFL.txt,assets/fonts/Caveat-OFL.txt,assets/audio/foley/KENNEY_CC0.txt'
    source = re.sub(r'^include_filter=.*$', lambda _: 'include_filter="' + includes + '"', source, flags=re.M)
    exclusions = 'specification/*,docs/*,tools/*,tests/*,test-results/*,work/*,artifacts/*,local-data/*,builds/*,*.psd,assets/locked_user/*,assets/display_user/*,assets/generated/*,assets/characters/*,assets/reference_gate/*,scripts/reference_gate/*,scenes/reference_fidelity_prototype.tscn*,scripts/rebuild/post_office_room.gd*,scripts/rebuild/title_screen.gd*,scripts/main.gd*,scripts/core/*,scenes/main.tscn*,data/game.json'
    source = re.sub(r'^exclude_filter=.*$', lambda _: 'exclude_filter="' + exclusions + '"', source, flags=re.M)
    preset.write_text(source, encoding='utf-8')
    print(f'Selected {len(paths)} resources from adopted AI manifest, current entry, fonts and licensed audio.')
    print('This updates packaging scope only; it does not prove all runtime roles are present or playable.')


if __name__ == '__main__':
    main()
