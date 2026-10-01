# Audio provenance and mix

Verified on 2026-10-01. The 27 files in `assets/audio/foley` total 2,779,667 bytes (about 2.65 MiB). All third-party recordings/foley below are **CC0 1.0**, permitting commercial reuse and adaptation. No account, private download, or payment was used. Freesound inputs are its publicly exposed high-quality MP3 previews, not the original lossless downloads. They were decoded, shortened, filtered, normalized, and encoded as mono 32 kHz WAV/OGG for this game.

| In-game files | Creator / source | What it is |
| --- | --- | --- |
| `paper_1/2/3`, `paper_slide`, `paper_unfold` | keweldog — [rustling paper.wav](https://freesound.org/people/keweldog/sounds/181774/) | Recorded paper handling; excerpts of the 4.830 s source |
| `bell` | JohnsonBrandEditing — [Ding Ding Small Bell](https://freesound.org/people/JohnsonBrandEditing/sounds/173932/) | First bell strike and decay; reduced peak to avoid the preview's above-full-scale transient |
| `door_open`, `door_close` | Iwan Gabovitch / qubodup — [Door open, door close](https://opengameart.org/content/door-open-door-close) | Author's room door recording; `door-01.flac` and `door-02.flac` from `door.7z` |
| `sea_bed` | jasinski — [alkaibeach.aif](https://freesound.org/people/jasinski/sounds/18363/) | Waves recorded at Alki Beach, Seattle; source may include distant human voices |
| `birds` | syncopika — [Bird chirping sounds](https://opengameart.org/content/bird-chirping-sounds) | Author's backyard recording; a short occasional detail, not a constant loop |
| `town_bed`, `room_bed` | MiLeuthner — [Residential neighborhood - Stereo Ambience](https://freesound.org/people/MiLeuthner/sounds/399028/) | Summer residential street and distant café; `room_bed` is a low-pass treatment of this recording, not a claimed indoor recording |
| `wind_bed` | nickydunne — [Wind in trees.WAV](https://freesound.org/people/nickydunne/sounds/463551/) | Tree wind, nearby small river and distant birds; source is not pure isolated wind |
| `tram_pass` | mdayalan — [Dublin's Luas Tram Arriving and Departing](https://freesound.org/people/mdayalan/sounds/239646/) | Recorded at Dundrum on Zoom H6; 8.5–22.5 s excerpt, quiet occasional station layer |
| `step_concrete_*`, `step_wood_*`, `step_grass_*`, `stamp_*`, `wood_piece`, `tool_metal` | Kenney — [Impact Sounds 1.0](https://kenney.nl/assets/impact-sounds) | CC0 game foley pack. Concrete/wood/grass footsteps, wood impacts as stamp/chess-piece foley, small metal impact as tool foley; no claim that a wood impact is a literal postal stamp recording |

The creator pages above explicitly list CC0. The Kenney archive's license is preserved in `assets/audio/foley/KENNEY_CC0.txt`. CC0 legal text: <https://creativecommons.org/publicdomain/zero/1.0/>. Credits remain here voluntarily even though CC0 does not require attribution.

`assets/audio/foley/source_downloads.json` records exact download URLs, input byte counts and SHA-256 hashes. It also lists three OpenGameArt wave excerpts evaluated during selection but **not shipped as samples**. `sample_manifest.json` records every shipped sample, source filename, excerpt time, duration, loop crossfade, filter cutoff, peak/RMS, byte count and hash. Downloaded source archives/previews are kept in the task's `work/audio_sources` staging directory rather than bloating the game repository. `tools/prepare_audio.py` documents the conversion procedure; provide that staging directory and FFmpeg 7.1 to reproduce it.

## Playback behavior

Seven locations have distinct mixes of four real-recording beds. The coast foregrounds sea/wind; civic streets foreground distant town activity; residential/chess areas foreground tree wind. Indoors replaces the outside town bed with its filtered derivative and reduces sea substantially. Location changes crossfade over roughly two seconds and remove an old location's ambient one-shot. The public API is `set_location(id, minute, indoors)`. Distant bird details occur at varied intervals; a tram passage only occurs at the bus-stop location. These layers are illustrative sound design, not a literal recording of the fictional Solmere town.

`StageWalker.footstep` follows actual distance travelled and stays silent while stationary. `play("step")` selects wood indoors, soft ground in residential/chess areas, and concrete elsewhere. Paper and footsteps avoid immediate sample repetition, have slight pitch variation, and reject same-frame repeats. Effects have cooldowns and a maximum of ten simultaneous one-shots. Music, effects and ambience have separate buses and `set_volumes(music, effects, ambience)` controls; toggle affects these game buses without changing the master bus.

The previous `assets/audio/afternoon.wav` remains a very quiet **procedurally synthesized musical motif**. It is not a real instrumental recording. Previous synthetic action/sea WAVs remain in the repository for history but the new controller does not select them. No generated noise is labeled or substituted as a field recording.

## Verification and limits

`tests/audio_smoke.gd` checks sample decoding, location mix differences, crossfade targets, indoor routing, cue cooldowns/variation, surface selection, independent mute/volume, and leaving an ambient one-shot behind. `tests/walker_smoke.gd` covers foot-contact timing plus movement/manual input. PCM preprocessing limits peaks to 0.6 or below and fades action edges; all shipped sample durations and levels are in the manifest. These are technical checks, **not a claim of a human listening acceptance pass**. A native listening pass in the final game is still needed to judge loudness and whether the source's distant voices suit a particular scene.
`test-results/audio_smoke_gpu.log` is the final 49-check real audio-backend run and exits without resource leaks. The headless Dummy backend passes the same assertions but reports pending AudioStreamPlayback references at shutdown; it is retained as a diagnostic, not the clean final audio run.
`暂停 → 声音设置` provides independent music/effects/ambience sliders and master mute. Preferences are saved to `user://audio_settings.cfg`, separately from game progress, and loaded at AudioFeedback startup. Mute preserves gains, including changes made while muted; a zero channel volume stays silent after unmute/restart. `tests/audio_settings_smoke.gd` passed 20 checks including restart persistence, invalid numeric values, actual slider/toggle signals and unchanged game state; evidence is in `test-results/audio_settings_smoke.log` and `audio_settings.png`.
