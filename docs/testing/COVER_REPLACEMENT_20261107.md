# Supplied cover replacement — 2026-11-07

Replaced the title illustration with the user's latest `封面.png`, byte-for-byte.
The runtime filename remains `assets/display_user/dear_somewhere_cover_USER_20261024.png` to preserve the explicit raw-asset export contract; its date is historical, not the new illustration's date.

- Original dimensions: 7262 × 4085. PNG bytes: 19,839,201.
- Source and packaged raw SHA-256: `23598989232c9b68ce2cb55a90ede364722e6a07d4563637d5a9513a5d88805f`.
- No repaint, added border, crop, or source downsampling. Original source outside the repository remains untouched; previous cover is retained in Git history.
- Disabled the old title-only sail shader attachment because its pixel coordinates refer to the previous illustration. Room and street motion remain unchanged.
- Kept existing bilingual title buttons and save paths. Visually checked both 1600 × 900 title renders: lettering and riders are unobscured, all buttons remain in bounds, and Settings opens in both languages.

## Validation

Built from main baseline `0354fbcbf323c1c5becf74bd70965f14ff5960e2` with only the cover and title script changed at runtime.

- Complete selected-resource packaging: 1110 entries, including 171 exact raw files; packer re-opened the PCK and verified every SHA-256.
- Final PCK SHA-256: `171f2233258f42876829a76b36ad57885fc5fbb62759dcae67cd553f2b9c77db`.
- Actual PCK loaded from an asset-free host: full-resolution cover, no old shader, six localized buttons in bounds, both Settings actions succeeded.
- Updated existing scene-motion coverage to treat the replacement cover as static; final-PCK GPU suite: **141 checks / 0 failures**. Existing room paper motion and crossfade checks still pass.
- Local evidence: `D:/Codex-build-cache/dear-somewhere-cover-20261107/qa/` and `motion-qa/`.

These are GPU rendering and engine interaction checks with isolated QA data. No OS input, user save changes, or claim of human playthrough acceptance.
