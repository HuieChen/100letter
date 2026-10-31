"""Copy the eight supplied street originals without re-encoding them."""
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('D:/电脑管家迁移文件/xwechat_files/wxid_iltlqlf3igrv22_6ce4/msg/file/2026-10')
DEST = ROOT / 'assets/authoring/streets_20261101'
FILES = {
    'community_morning.png': '清晨3(3).png',
    'community_noon.png': '中午3.png',
    'community_sunset.png': '下午3.png',
    'community_night.png': '夜晚3.png',
    'residential_morning.png': '清晨4.png',
    'residential_noon.png': '中午4.png',
    'residential_sunset.png': '下午4.png',
    'residential_night.jpg': '夜晚4.jpg',
}

def main():
    DEST.mkdir(parents=True, exist_ok=True)
    entries = []
    for target, original in FILES.items():
        source = SOURCE / original
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        shutil.copyfile(source, DEST / target)
        assert hashlib.sha256((DEST / target).read_bytes()).hexdigest() == digest
        with Image.open(source) as im:
            size = list(im.size)
        entries.append(dict(file=target, supplied_name=original, sha256=digest, size=size, processing='none; exact source bytes'))
    (DEST / 'provenance.json').write_text(json.dumps(entries, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(entries, ensure_ascii=False))

if __name__ == '__main__':
    main()
