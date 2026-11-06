# Album export and corrected dialogue composition

The photo review now has Save to album and, after success, Open album. It writes a developed PNG (full landscape capture, cream paper and current note) to the system Pictures directory under `Dear Somewhere`. Normal prints are 1808 x 1240; long notes extend the writing margin instead of being silently clipped. Text is rasterized at output resolution. Original captures and caption sidecars remain in the game's photo collection. Exports use unique filenames, reject duplicate in-flight activation and show storage failures without claiming success. Empty or unreadable photos cannot be exported. QA redirects exports to isolated `user://qa/` folders.

The latest user correction selects the exact `对话框-牛皮纸-弱纹理 2(1).png`, retained as `paper_dialogue_weak_v3.png`. SHA-256: `288cbc415d4333f7e00df9809b7c4a3781d73aefce9b7631a512f32af7139544`. No pixels or alpha were repainted; atlas sampling excludes transparent padding. The final integration retains main's 40-pixel portrait lift, speaker wrapping fix, arrow/text bounds, atomic PNG replacement and pending-save close handling from `bc8d458`. It adds direct output-resolution caption rendering and Open album. Concurrent commits are preserved; the earlier local 35-pixel variant is not the selected release.

## Verification

Godot 4.7.2, GPU Compatibility renderer, isolated QA data:

- `photo_album_visual_20261107.gd`: 98 checks, zero failures on the final merged runtime. Actual synthetic pointer activation, rapid duplicates, full left/right image landmarks, baked note ink, empty note without placeholder, long-note final line, unique files, original SHA preservation, blocked storage recovery, corrupt/empty albums, and Chinese/English layouts at 1280/1920/2560.
- Retained `photo_album_export_20261107.gd`: 54 checks, zero failures. Retained `host_photo_export_close_20261107.gd`: 7 successful-export and 8 failed-export shutdown checks, zero failures, on the merged runtime.
- `photo_review_resilience.gd`: 64 checks, zero failures. Retained current-photo identity after failed loading, note persistence and review focus containment.
- `feedback_landscape_20261106.gd`: 72 checks, zero failures. Real capture/review/bag flow, full landscape composition, map destinations, door and transition boundaries.
- Final merged `dialogue_paper_20261107.gd`: 222 checks, zero failures; grocery and chef scenes, both languages, 1280/1920/2560, source hash and dialogue input boundaries. Earlier 16-check local 35-pixel evidence is retained but is superseded by this merged 40-pixel implementation.

Local evidence is under `new-chat/work/album-dialogue-20261107/` (final export evidence: `album-qa-merged`) and `new-chat/work/dialogue-followup-20261107/`. Earlier `album-qa` and `album-qa-crisp` evidence is retained; the final output-resolution typography correction removes 2x label scaling blur. Deliberately invalid directory/PNG fixtures produce expected diagnostics. The dialogue render retains known raw-image warnings; the release pipeline explicitly includes those exact PNG bytes.

No OS input was resumed after the user's interruption, and tests did not write to the player's Pictures folder. Native usability and human visual acceptance remain separate from these checks. Packaging must use the new main commit, preserve concurrent changes, and update both Latest launch directories; the prior release is not evidence for this revision.
