# Camera shutter feedback — 2026-11-09

Camera feedback was mapped to `snap`, a quiet paper-slide recording at -18 dB, and emitted only after PNG writing. The camera now has a dedicated original procedural mechanical double-click, emitted once when a capture is accepted. The existing busy/closing/gallery guards prevent extra sounds; failed writes remain errors, not successful-photo notifications.

The short 180 ms non-looping waveform is generated and cached once, with a bounded peak, two damped transients and no downloaded samples. Playback uses the existing effects bus at -8 dB, follows effects volume and master mute, and leaves the guitar/ambience players and settings `snap` unchanged. Original art and recordings are not modified.

The actual Host regression checks immediate trigger before disk completion, duplicate prevention, native playback, waveform energy/peak, photo save, failure recovery, mute/restore and continuous music voice: 17 checks passed. Offscreen engine tests do not establish human listening acceptance. Final-PCK results accompany publication.
