"""Release the observed small roadside blade, without changing source pigment.

This reuses the same source-aware, fixed-root clearance construction used for
the other streets. Only the specified technical mask window may change.
"""
import json
from pathlib import Path
import sys

import build_motion_grass_clearance_20261106 as clearance

clearance.SPECS = {
    "community": {
        "source": "assets/authoring/streets_20261101/community_noon.png",
        "source_sha256": "1367346a083df03e2ecfe1f5d8f97951bb61acc55ed0f3b60dda1fc817ce00f8",
        "source_size": (9204, 640),
        "windows": [(1003, 474, 1030, 515)],
        "supports": [],
    }
}

if __name__ == "__main__":
    result = json.dumps(clearance.build("community"), indent=2)
    if len(sys.argv) > 1:
        Path(sys.argv[1]).write_text(result, encoding="utf-8")
    print(result)
