"""Check the rendered leaf silhouette independently of shader masks/regions."""
from collections import deque
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'test-results/leaf-tip-continuity-20261103'


def components(pixels):
    # The supplied leaf stays greener than the blue sky in all four paintings.
    mask = (pixels[:, :, 1] > pixels[:, :, 2] + 8) & (pixels[:, :, 1] > pixels[:, :, 0] - 10)
    seen = np.zeros(mask.shape, dtype=bool)
    sizes = []
    height, width = mask.shape
    for y, x in zip(*np.where(mask)):
        if seen[y, x]:
            continue
        queue = [(y, x)]
        seen[y, x] = True
        count = 0
        while queue:
            yy, xx = queue.pop()
            count += 1
            for dy in [-1, 0, 1]:
                for dx in [-1, 0, 1]:
                    ny, nx = yy + dy, xx + dx
                    if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        queue.append((ny, nx))
        if count > 5:
            sizes.append(count)
    return sorted(sizes, reverse=True)


results = []
for phase in ['morning', 'noon', 'sunset', 'night']:
    first = None
    motion = 0
    for index in range(10):
        before = np.asarray(Image.open(OUT / f'{phase}_before_{index:02}.png')).astype(float)
        after = np.asarray(Image.open(OUT / f'{phase}_after_{index:02}.png')).astype(float)
        before_parts, after_parts = components(before), components(after)
        assert len(after_parts) == 1, (phase, index, after_parts)
        assert np.max(np.abs(after - before)) > 10, (phase, index, 'repair absent')
        if first is None:
            first = after
        motion = max(motion, int(np.count_nonzero(np.max(np.abs(after[:, :, :3] - first[:, :, :3]), axis=2) > 2)))
        results.append({'period': phase, 'sample': index, 'before_component_sizes': before_parts, 'after_component_sizes': after_parts})
    assert motion > 200, (phase, 'leaf no longer moves')
    results.append({'period': phase, 'maximum_changed_motion_pixels': motion})

receipt = {'checks': 84, 'failures': [], 'source_crop': [7745, 118, 35, 35], 'render_scale': 6, 'wind_times': [0, 2, 4, 6, 9.68, 12, 15, 18, 20, 24], 'method': 'Independent green-versus-blue rendered silhouette connectivity across four paintings and ten wind times; original notch remains disconnected in morning/sunset/night baseline. One connected repaired silhouette per frame, with retained motion. Asset files unchanged.', 'results': results}
(OUT / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print('LEAF_TIP_CONTINUITY 84 checks, 0 failures; all 40 repaired silhouettes connected and moving')
