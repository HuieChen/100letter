# Map and photo review navigation — 2026-11-07

A stationary pointer could keep the map marker over one destination after Tab moved keyboard focus elsewhere; Enter then travelled to a different destination from the marker. The marker now follows the most recent real navigation input. Pointer motion inside the same building restores hover feedback, while programmatic focus changes do not override mouse feedback. Original map art and press feedback remain unchanged.

An unreadable photo could trap the next/previous buttons on the same failed filename. A separate browsing cursor now tracks attempted navigation while the visible print index continues owning caption edits and exports. Further clicks reach later files without misassigning notes. Tab and Shift+Tab leave the caption editor without inserting indentation; a focused page arrow keeps focus across successful page turns. Empty and single-photo galleries disable paging, including after export.

The upstream a727a46 sharp caption rendering and Open album access are retained. No original artwork, portrait positions, hidden story flow or player save format changed.

## Verification

Actual PCK SHA256: `027740aefdbd27d1dc0f27304fcc987040b73e7af7b89afeba86579938c093dc`.

535 focused checks passed using the frozen package from empty hosts with isolated userdata, offscreen GPU and engine-injected inputs:

| Suite | Passed |
|---|---:|
| Map mouse/keyboard transitions, selection and arrival | 44 |
| Photo review navigation, Tab, mixed/empty/single/corrupt galleries | 90 |
| Existing photo review resilience | 64 |
| Photo album export | 54 |
| Caption export rendering and failure feedback | 98 |
| Map/door/landscape photo regression | 72 |
| Open exploration routes | 113 |

Release EXE booted for 120 GPU frames and exited 0. Map screenshots and photo review layouts were inspected. Corrupt PNG and blocked output-directory fixtures intentionally emit decoding/write errors; these are retained in the logs. No unexpected script/parse/leak errors were found. Test counts are not human playthrough or artistic acceptance. Broader narrative/CORE-BOOK remains outside this focused correction.
