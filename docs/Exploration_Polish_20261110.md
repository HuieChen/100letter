# Exploration and field recording — 2026-11-10

Current human request: implement the full approved photography, recording, navigation and audio polish, retain current supplied artwork and narrative scope, validate against the researched interactions, then push GitHub main. Recorder implementation is explicitly authorized, superseding the November 6 recorder freeze. User rejected sentimental/generated-sounding prompts; runtime copy uses short operation labels only.

References: SEASON (directional auditory focus and actual recorded sound), TOEM (observation and framing), Umurangi Generation (photographic expression), A Short Hike (responsive exploratory movement). These are acceptance criteria, not claims that our game matches those complete games.

Scope ledger (in progress):
- Camera: continuous capture, optional print review, preserved adjustments, pan alongside controls, original comparison, style previews, basic/advanced controls, actor visibility, focus feedback, saved originals, favorite/review/notes/export clarity.
- Recording: spatial sources, directional pickup, real ambient-bus recording, start/stop/playback, visual direction option, levels, persistent names/library, focus loss/close/error recovery, bilingual layouts.
- Navigation: click landing feedback, contextual object response, reliable cancellation, current map position, unique arrivals, preserve current free exploration time rules.
- Atmosphere: use existing authored motion; select meaningful existing bird/cloth/water moments; tie positional sound to actual scene geometry. No source-image redrawing or invented character poses.
- Sound: preserve user guitar, quiet differentiated UI cues, avoid stacked voices, smooth exploration/recording/playback transitions; captured audio and actual listening evidence distinguished.
- Integration: source and actual exported package, settings/focus/modal safety, original saves isolated, fetch/merge collaborator changes, normal main push and matching playable output.

Do not advance unrelated historical CORE-BOOK/story gates or label missing native/listening/novice checks passed. Role reviews execute sequentially; no delegated agents.

## Recorder UI correction and visual reference

Latest user correction supersedes the first bottom-panel implementation: no large panel may obscure the scene while monitoring or recording.

- Visual reference inspected: SEASON in-game recording screenshot published by [Shacknews](https://www.shacknews.com/article/133862/season-letter-to-the-future-review-score). Sparse recording status and lower-right action prompts, with no opaque software dashboard. Our adaptation puts the meter/time at the upper-left and small controls along the edges; center stays clear. No reference pixels are used as game assets.
- Primary design source: [SEASON audio team at Side](https://side.inc/lab/season-a-letter-to-the-future-experiencing-audio-recording-as-a-game-mechanic) and [Scavengers Studio on PlayStation Blog](https://blog.playstation.com/2022/06/02/discover-the-gameplay-and-story-of-season-a-letter-to-the-future/). Monitoring changes perspective; recording stores actual audio; reviewing recordings is a separate activity.
- The linked Audiokinetic video page was verified but its player reported unavailable. Layout was verified from the actual gameplay screenshot instead; no claim of watching that video or hearing its soundtrack.
- Live HUD has no opaque panel. Library is opt-in, disabled while recording and automatically hidden when recording begins. Main scene rectangle (400,170)-(1200,770) is clear of persistent controls at the 1600x900 design scale. Direction cue is optional and uses only a thin outline.
- R starts/stops, P plays/stops playback, H toggles direction cue; Esc and × put the recorder away. No microphone permission or external recording is used.

## Sequential review responsibilities

Design: tools work as usable activities before the main story, no invented quests or rewards. Art: existing source images, character poses, map and guitar retained. Implementation: isolated branch, actual Godot bus PCM capture, atomic metadata and recoverable audio save failure. Adversarial QA: keyboard focus, repeated capture, exports, close during capture, recording focus loss, disk write failure/retry, saved names and restoration. Audio: separate ambience capture from UI/music, source attenuation/direction, limited playback gain (+12 dB maximum, 6 dB peak headroom), music and ambience transitions remain continuous. These are sequential passes by one agent, not independent human approvals.

Source voice locations reuse painted bird anchors and tree crown regions. Existing authored water, cloth and plant animations continue unchanged. This is a focused interaction polish release, not main-story or whole-game aesthetic acceptance.
