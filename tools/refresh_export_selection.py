"""Refresh selected resources from reviewed generated art and the explicit video override.
No download, model invocation, source art editing, or publication occurs here.
"""
from pathlib import Path
import json
import re
import hashlib

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'assets/faefever_v2/manifest.json'


def selection(retained_paths=()):
    catalog = json.loads(MANIFEST.read_text(encoding='utf-8-sig'))
    entries = catalog.get('assets', {})
    if not entries:
        raise ValueError('No adopted final artwork has been registered.')
    # Explicit 2026-10-19 user override: the two-room postal interior is exact
    # authored art, not an ImageGen role. Keep the exception pinned and narrow.
    room_path = 'res://assets/authoring/post_office_20261019/room_pair.jpg'
    room_provenance = ROOT / 'assets/authoring/post_office_20261019/provenance.json'
    room_info = json.loads(room_provenance.read_text(encoding='utf-8'))
    room_hash = hashlib.sha256((ROOT / room_path[6:]).read_bytes()).hexdigest()
    if (room_info.get('source_kind') != 'user_supplied_scene_exact_bytes'
            or room_info.get('ai_generated') is not False
            or room_hash != room_info.get('sha256')
            or room_hash != '5bef8c44b16c09eb31d60395b6b4d56b11b574d9ba70acdd2ccb2f8de1e04e8b'):
        raise ValueError('Supplied postal interior differs from the authorized original.')
    paths = {'res://scenes/final_slice.tscn',
             'res://scripts/rebuild/field_book.gd',
             'res://scripts/rebuild/field_observation.gd',
             'res://assets/fonts/SolmereSans.ttf',
             'res://assets/fonts/Caveat.ttf', room_path}
    # Upstream runtime types also refer to each other by class_name. Include
    # their resource graph explicitly instead of relying only on quoted paths.
    for addon in ('phantom_camera', 'dialogue_manager'):
        for path in (ROOT / 'addons' / addon).rglob('*'):
            if path.is_file() and path.suffix.lower() in {'.gd', '.tres', '.tscn', '.svg', '.png', '.ttf', '.translation'}:
                paths.add('res://' + path.relative_to(ROOT).as_posix())
    # The preset also records later explicit runtime adoptions (street art,
    # shaders and authored dialogue). Refreshing the older catalog must not
    # silently undo those reviewed selections.
    for path in retained_paths:
        if (not path.startswith('res://') or '..' in Path(path[6:]).parts
                or not (ROOT / path[6:]).is_file()):
            raise ValueError(f'Existing selected runtime resource is missing or invalid: {path}')
        paths.add(path)
    for key, entry in entries.items():
        authorized_video = (isinstance(entry, dict) and key in {'CHAR_courier','CHAR_courier_walk',
                            *('CHAR_courier_walk_'+str(i) for i in range(5))}
                            and entry.get('source_kind') == 'user_video_extraction'
                            and entry.get('source_video_sha256') == catalog.get('user_animation_override',{}).get('source_video_sha256')
                            and len(entry.get('source_video_sha256','')) == 64)
        authorized_pdf = (isinstance(entry, dict) and key in catalog.get('settings_ui_override', {}).get('scope', [])
                          and entry.get('source_kind') == 'user_pdf_embedded_image_exact_bytes'
                          and entry.get('source_pdf_sha256') == catalog.get('settings_ui_override', {}).get('source_pdf_sha256')
                          and entry.get('source_pdf_sha256') == 'ff54771c8c7d98ee2d9cfeeac496eb203a324ebc96a3b9a5dcba9853f19c191f')
        if not isinstance(entry, dict) or not (entry.get('ai_generated') is True or authorized_video or authorized_pdf):
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
    source_suffixes = ('.gd', '.gdshader', '.gdshaderinc', '.tscn', '.tres')
    pending = [path for path in paths if path.endswith(source_suffixes)]
    visited = set()
    while pending:
        resource = pending.pop()
        if resource in visited:
            continue
        visited.add(resource)
        local = ROOT / resource[6:]
        if not local.is_file():
            raise ValueError(f'Missing runtime source dependency: {resource}')
        if resource.startswith(('res://addons/phantom_camera/', 'res://addons/dialogue_manager/')):
            # These complete upstream graphs were selected above. Their editor
            # utilities also mention optional upstream test/example paths.
            # Treating every such string as our game dependency is incorrect.
            continue
        source = local.read_text(encoding='utf-8-sig')
        for dependency in re.findall(r'''res://[^"'\s]+\.(?:gdshaderinc|gdshader|gd|tscn|tres|ttf)(?=["'\s])''', source):
            if dependency not in paths:
                paths.add(dependency)
                if dependency.endswith(source_suffixes):
                    pending.append(dependency)
    # This directory contains licensed local playback clips, not reference media.
    for path in (ROOT / 'assets/audio').rglob('*'):
        if path.is_file() and path.suffix.lower() in {'.wav', '.ogg'}:
            paths.add('res://' + path.relative_to(ROOT).as_posix())
    return sorted(paths)


def refreshed_source(source):
    """Return a refreshed preset without touching the shared file (also for QA)."""
    source = source.replace('\r\n', '\n')
    existing = re.findall(r'^export_files=PackedStringArray\((.*)\)$', source, re.M)
    if len(existing) != 1:
        raise ValueError('Expected exactly one export selection.')
    paths = selection(re.findall(r'"(res://[^"\n]+)"', existing[0]))
    line = 'export_files=PackedStringArray(' + ', '.join(json.dumps(x) for x in paths) + ')'
    source, count = re.subn(r'^export_files=.*$', lambda _: line, source, flags=re.M)
    if count != 1:
        raise ValueError('Expected exactly one export selection.')
    includes = 'data/rebuild/*.json,assets/faefever_v2/manifest.json,assets/faefever_v2/characters/courier_walk_regions.json,assets/faefever_v2/characters/courier_video_provenance_20261017.json,assets/fonts/OFL.txt,assets/fonts/Caveat-OFL.txt,assets/fonts/DynaPuff-OFL.txt,assets/fonts/LilitaOne-OFL.txt,assets/fonts/NotoSansSC-OFL.txt,assets/fonts/ChillRoundF-OFL.txt,assets/fonts/ZCOOLKuaiLe-OFL.txt,assets/fonts/settings-font-provenance.json,assets/audio/foley/WATER_CC0.txt,assets/audio/foley/water-provenance.json,assets/audio/foley/KENNEY_CC0.txt,assets/audio/SETTINGS_MUSIC_CC0.txt,assets/audio/settings-music-provenance.json,third_party/webgl-water/LICENSE-MIT.txt,third_party/webgl-water/upstream.json,assets/faefever_v2/ui/settings_pdf_20261017/provenance.json'
    current_includes = re.findall(r'^include_filter="([^"]*)"$', source, re.M)
    if len(current_includes) != 1:
        raise ValueError('Expected exactly one include filter.')
    # Preserve the exact current raw-file patterns, including dialogue, source
    # panoramas, masks and original animation frames. Add only exact include
    # dependencies discovered from runtime source; never broaden to assets/*.
    patterns = [x.strip() for x in (current_includes[0] + ',' + includes).split(',') if x.strip()]
    patterns.extend(['addons/phantom_camera/LICENSE', 'addons/dialogue_manager/LICENSE', 'data/dialogue/chef_zh.dialogue', 'data/dialogue/chef_en.dialogue'])
    patterns.extend(path[6:] for path in paths if path.endswith('.gdshaderinc'))
    includes = ','.join(dict.fromkeys(patterns))
    source = re.sub(r'^include_filter=.*$', lambda _: 'include_filter="' + includes + '"', source, flags=re.M)
    exclusions = 'specification/*,docs/*,tools/*,tests/*,test-results/*,work/*,artifacts/*,local-data/*,builds/*,*.psd,assets/locked_user/*,assets/display_user/*,assets/generated/*,assets/characters/*,assets/reference_gate/*,scripts/reference_gate/*,scenes/reference_fidelity_prototype.tscn*,scripts/rebuild/post_office_room.gd*,scripts/rebuild/title_screen.gd*,scripts/main.gd*,scripts/core/*,scenes/main.tscn*,data/game.json'
    current_exclusions = re.findall(r'^exclude_filter="([^"]*)"$', source, re.M)
    if len(current_exclusions) != 1:
        raise ValueError('Expected exactly one exclude filter.')
    exclusions = ','.join(dict.fromkeys(
        x.strip() for x in (current_exclusions[0] + ',' + exclusions).split(',')
        if x.strip() and x.strip() != 'assets/display_user/*'))
    # Only the specifically adopted cover may pass build.ps1's display_user
    # audit. A blanket folder exclusion would also remove that authorized file.
    source = re.sub(r'^exclude_filter=.*$', lambda _: 'exclude_filter="' + exclusions + '"', source, flags=re.M)
    return source, paths


def main():
    preset = ROOT / 'export_presets.cfg'
    source, paths = refreshed_source(preset.read_text(encoding='utf-8-sig'))
    preset.write_text(source, encoding='utf-8')
    print(f'Selected {len(paths)} resources from reviewed art, explicit courier-video override, current entry, fonts and licensed audio.')
    print('This updates packaging scope only; it does not prove all runtime roles are present or playable.')


if __name__ == '__main__':
    main()
