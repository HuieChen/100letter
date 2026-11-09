# Camera lab and attached captions — 2026-11-10

Design references (reviewed 2026-11-09/10):
- Fujifilm X-Pro3 image-quality manual: film simulations with separate grain and tone controls. https://app.fujifilm-dsc.com/en/manual/x-pro3/menu_shooting/image_quality_setting/index.html
- PlayStation's Ghost of Tsushima photo-mode guide: composition and visual treatment in a dedicated mode. https://blog.playstation.com/2020/07/16/ghost-of-tsushima-photo-mode-gallery-and-tips-guide/
- Pupperazzi developer announcement about photographic filters: https://store.steampowered.com/news/app/1028350/view/4135958413712494149 (search result located; full-page retrieval failed).
- TOEM official store: photography as the core exploratory interaction. https://store.playstation.com/en-us/concept/10003267

Implementation: 12 original artistic instant/film recipes plus unfiltered original. Six controls: exposure EV, warmth, green/magenta tint, saturation, grain, simulated aperture. Right click picks a radial 2D focus point; f/8 is sharp. This is a deliberate 2D simulation, not physical depth reconstruction or branded film reproduction. Horizontal and square instant prints remain independent from filters. Live preview and captured pixels share the same shader; recipe metadata accompanies saved PNGs and survives caption editing. Existing photo files remain unchanged.

Caption hierarchy: bag caption is a child of the print; review editor is a child of the print. Export uses paper-relative coordinates. Tests check bound caption movement, metadata preservation and composite export.

Development QA: first packaged candidate failed because a GDScript constant shadowed Shader; first source-render candidate caught illegal shader TEXTURE scope and nil focus metadata. Both corrected. Source QA 33/0 then passed (13 distinct rendered recipes, capture, caption, composite export); final package validation tracked separately below.

Final merged package QA: camera lab 35/0, composition 20/0, landscape/caption 72/0, pending capture close 6/0, 240-photo pocket streaming 70/0 (203 checks total). Existing tests updated for caption-local coordinates and the new map dog hotspot. Evidence qa-lab-final-013803, 015938, 020411. PCK FFF192F1D5FC62565B649A810AE451126A0B2FECA1E3E73EFFC5C90526174A73. Actual native input acceptance remains separate.
