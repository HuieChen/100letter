"""Register unchanged ImageGen outputs with dimensions, alpha bounds and provenance."""
import argparse, hashlib, json, shutil
from pathlib import Path
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument("batch")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
manifest_path = root / "assets/faefever_v2/manifest.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {"style_lock":"SOLMERE_FAEFEVER_2D_V1","assets":{}}
batch = json.loads(Path(args.batch).read_text(encoding="utf-8"))
for item in batch:
    source = Path(item["source"])
    relative = Path(item["path"].removeprefix("res://"))
    destination = (root / relative).resolve()
    if root not in destination.parents:
        raise ValueError("Asset destination is outside the project")
    if source.suffix.lower() != ".png":
        raise ValueError("Expected an unchanged ImageGen PNG")
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    with Image.open(destination) as image:
        item["native_dimensions"] = list(image.size)
        item["mode"] = image.mode
        if "A" in image.getbands():
            bounds = image.getchannel("A").point(lambda value: 255 if value > 128 else 0).getbbox()
            if bounds:
                item["alpha_bounds"] = list(bounds)
                item["region"] = [bounds[0], bounds[1], bounds[2]-bounds[0], bounds[3]-bounds[1]]
        item["sha256"] = hashlib.sha256(destination.read_bytes()).hexdigest()
    key = item.pop("key")
    manifest["assets"][key] = item
    print(key, item["native_dimensions"], item.get("region"), item["sha256"][:12])
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
