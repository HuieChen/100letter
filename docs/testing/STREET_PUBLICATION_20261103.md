# Street atmosphere publication — 2026-11-03

## Selected implementation

Preserve the four November community panoramas byte-for-byte and all supplied character paintings. Local vegetation bends around fixed attachments; long fronds lag and short grass recovers faster. Sea motion uses a different low-amplitude response. Building, lamp, flag-pole, cabinet and plant-support guards prevent rigid painted objects from moving. These are restrained procedural 2D effects, not a general fluid or plant physics solver. Actual morning/noon/sunset/night paintings blend at matching coordinates; existing game time, saves and settings remain authoritative.

The existing guitar stays primary. Quiet CC0 leaf, wind and sea beds follow the shared wind/wave envelope and retain actual audio-bus volume/mute behavior. Credits and the new leaf recording's source/license/hash are included. Original five-pose walking remains selected; the rejected generated leg rig is not exported. Human gait and listening acceptance are still open.

## Final regression and repair

An older visibility test wrongly required two candidate rectangles containing cabinets/fruit supports to move as if they were grass. The test now explicitly checks those supports stay fixed, while retaining all actual vegetation/water checks. This stronger assertion exposed 23 moving cabinet pixels at x=4513–4529. Extending the existing grocery guard from x=4510 to x=4540 fixed the actual defect. No image bytes or other wind parameters changed.

After that fix, hidden offscreen GPU runs returned exit0 with empty stderr:

- `street_atmosphere_check`: 131 checks, 0 failures.
- `street_object_boundaries`: 198 checks, 0 failures.
- `street_motion_visibility`: 28 candidate plant/water areas, two non-plant supports stationary, 22 rigid guards at noon and night, unchanged ground, 0 failures.
- Updated street/import check previously passed 93/0 against these exact four supplied panoramas.

Current test logs use `test-results/publication-cabinet-*-20261103` (ignored local evidence). Tests do not establish aesthetic acceptance or realtime performance. Native automation initialization failed during this task; a new manual playthrough was not performed.

## Video evidence and limits

`Community_Object_Motion_Corrected.mp4`: 64.00 seconds, 1920×1080, 60fps, 3840 frames, 28,234,452 bytes. SHA256 `68d4fceb42073510074eddcd4c2f03d171c54cf9147c98485d2b6cc5fa356f6d`. Root independently verified file hash and decoded the full audio/video stream with zero errors. The recording forces one GPU draw per logical frame; it is accelerated-day scripted review footage, not measured native gameplay. Original soundtrack retained. See `street-local-motion-20261102/receipt-20261103.json` for the recorded snapshot.

The video predates only the final cabinet-guard width correction above. Do not describe its historical source hashes as those of the final publication. Earlier PCK-overlay recordings loaded old compiled `.gd.remap` helpers and are superseded. New builds must export current source directly; file-hash verification of raw overlays alone is insufficient.

The latest user instruction is direct chat video delivery, not WeChat. No video is committed to source control. No claim of full-game or user acceptance is made.

## Fresh Windows export

Exported `DearSomewhere.exe` and `DearSomewhere.pck` to the ignored local `test-results/DearSomewhere-Atmosphere-20261103/` folder. An isolated GPU process loaded only that fresh PCK, without source overlays: 14 checks passed, zero failures and empty stderr. It verified the actual compiled material has 22 rigid guards, 15 grass regions and the final cabinet extent x=4540; all four image SHA-256 values match the supplied originals; the packaged leaf OGG decodes and its license is present; all four daylight states render.

The export scan emitted an existing invalid Blender-path warning. No Blender resource is needed by this change; export completed and the fresh package checks above passed. This is a local Windows build, not a newly published GitHub Release installer.
