# Supplied dialogue paper and photo album export — 2026-11-07

The last supplied `对话框-牛皮纸-弱纹理 2(1).png` now replaces the earlier paper by exact byte copy. The atlas removes only transparent outer margins. Both conversation portraits move up 40 authored pixels. The speaker label no longer acquires a large wrapped minimum height; the text region and drawn advance arrow have separate input bounds. Masked dialogue and the existing demo scope remain intact.

Photo review now offers Save to album / 保存到相册. It writes a full landscape PNG with the print border and saved bilingual caption to the system Pictures/Dear Somewhere directory. Unique filenames preserve previous exports and originals. A temporary file is renamed after successful PNG output. Failed writes retain the note and show a retry message; repeated clicks cannot start concurrent exports. A close request during the final render frame waits for completion and then exits without a false save error. Long captions extend the print, with a bounded maximum image size.

This change retains the upstream map/door feedback, neutral transition, typography, local scene motion, and photo-pocket streaming (5350a34). Runtime source: `bc8d45827154a4156ef5ce0e078fd54cf581b2e6`. Actual PCK SHA256: `6cec07b43b3cdf1125e1146ef464970518063526c9938495e5645a61b37ed4e0`.

## Validation

743 focused checks passed on this exact exported PCK in an asset-free host, with isolated userdata and offscreen GPU/engine input:

| Suite | Passed |
|---|---:|
| Supplied paper, cast, marker geometry, zh/en at 1280/1920/2560, Enter/Esc | 222 |
| Album PNG export, caption pixels, failures, repeat input | 54 |
| Photo review resilience | 64 |
| Close window during successful/failed export | 7 + 8 |
| Map/door feedback and landscape photo composition | 72 |
| Managed chef conversation | 75 |
| Open exploration routes | 113 |
| Comfort and interaction flow | 58 |
| Photo pocket streaming | 70 |

The official release executable also booted for 120 GPU frames and exited 0. Runtime-export Python tests: 3 passed. Build inventory verified selected resources and explicit raw files against packed SHA256. Dialogue captures and exported prints were visually inspected. Expected corrupt-photo and blocked-path negative-fixture messages are retained in logs; existing raw-image import warnings remain. No unexpected script/parse errors occurred.

These checks are not a human playthrough, listening acceptance, or completion of the broader narrative/CORE-BOOK task. Source images and existing player saves remain preserved.
