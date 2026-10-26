# Envelope model removal — 2026-10-26

Request: remove the previously created Blender envelope.

Removed the independent authoring model directory (Blender source, glTF export, three previews, reference copy and metadata) and its generator from the project. A local recovery copy is stored outside the repository. The external user original is untouched.

Validation: searched scripts, scenes, project configuration and the remaining repository for the model directory, model filenames and generator; no live references remain. The asset was not wired into the 2D game, so no gameplay or save migration is needed. No runtime interaction changes were made; no broad playtest is claimed.
