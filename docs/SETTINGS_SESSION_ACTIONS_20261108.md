# Settings session actions and cover feedback

In-game Settings now exposes **Save & return to title** and **Quit game** below the settings card. The corner cross still closes Settings to its caller. Title Settings exposes Quit without a redundant return action. The pause menu retains Resume, Settings and Save/title, and adds Quit. The title has a secondary Quit action and Escape opens its confirmation.

Quit defaults to Keep playing. Cancel/X/Escape returns to the opening Settings or pause control. Confirm uses the existing guarded campaign/draft save and audio shutdown. Failed campaign writes leave the window and controls available; returning to title uses the same save guard. No save format or user artwork changed.

Cover paper feedback now keeps the authored lettering at its original scale. One selected paper lifts vertically by three logical pixels, contacts at two pixels on press, and settles in 120 ms. Pointer entry transfers focus so a previous keyboard selection cannot remain lifted simultaneously. Hit rectangles remain stationary.

## Verification

- Integrated source: `141e8896ae53601553777139cd8fe3da4d778afc`, preserving main `aec325e9b7a27fc4c3dbc3972697d39a96b4d303` and its bag, input, map and grass changes.
- Release PCK SHA-256: `6f9f345555e18c8d22c542da6d3756cd7a54a5f6e863f7d3957a9dc2eb3376d6`.
- Official Windows release EXE SHA-256: `d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562`.
- Pack inventory: 1118 resources; all 172 explicit raw files verified.
- Actual PCK from an empty host directory: title paper 29/0, title/Settings exit 32/0, Settings focus 144/0, bag navigation 30/0, real title quit 1/0, real in-game Settings quit 1/0. Total **237 checks, zero failures**. Both real quit processes returned zero through the production save/audio shutdown path. No script errors or leaked-resource warnings in these six logs.
- Isolated artifacts: `D:/Codex-build-cache/dear-somewhere-exit-20261108/qa-final-211452/`. English and Chinese Settings screenshots included. Failure injection used only QA-owned paths and preserved the sentinel file.
- Native window inspection: exact cover art and secondary Quit visible; Continue entered post office; its Settings gear opened the page with both footer actions. Keyboard navigation and Return activated Save/title and visibly returned to the cover. Escape displayed quit confirmation with Keep playing initially focused. Native-window evidence is separate from automated checks; visual feel remains subject to the user's acceptance.

An earlier candidate failed type inference in the new Settings return-origin flag; it was fixed with an explicit boolean and is not the released package. A temporary export ZIP was corrupted with C: nearly full; process-local TEMP/TMP on D: produced the subsequently verified package, without modifying global Windows configuration or deleting user data.
