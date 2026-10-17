"""Source-fidelity checks for the latest original five-frame courier cutout."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/faefever_v2/characters"
ATLAS = ASSETS / "courier_video_20261017.png"
IDLE = ASSETS / "courier_video_idle_20261017.png"
PROVENANCE = ASSETS / "courier_video_provenance_20261017.json"
SOURCE_SHA = "f8af71a6daa7a620aa07887528da4e7151e8f55320c525c7bf7d9122f1b3f4a5"
APPROVED_ATLAS_SHA = "1e21e4a48fba1ae3941134da42c38ce652c164a7b795c6ac517da5a745906b9c"
spec = importlib.util.spec_from_file_location("courier_original_20261017", ROOT / "tools/extract_video_courier_20261017.py")
EXTRACTOR = importlib.util.module_from_spec(spec)
spec.loader.exec_module(EXTRACTOR)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class VideoCourier(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.geometry = json.loads((ASSETS / "courier_walk_regions.json").read_text(encoding="utf-8"))
        cls.manifest = json.loads((ROOT / "assets/faefever_v2/manifest.json").read_text(encoding="utf-8"))
        cls.provenance = json.loads(PROVENANCE.read_text(encoding="utf-8"))
        cls.atlas = Image.open(ATLAS).convert("RGBA")
        cls.poses = [np.asarray(cls.atlas.crop((i * 320, 0, (i + 1) * 320, 500))) for i in range(5)]

    def test_all_five_original_frames_keep_chronology_and_source_timing(self):
        g, p = self.geometry, self.provenance
        self.assertEqual(g["source_kind"], "user_video_extraction")
        self.assertEqual(g["frame_count"], 5)
        self.assertEqual([frame["source_frame"] for frame in g["frames"]], [0, 1, 2, 3, 4])
        self.assertEqual([frame["key"] for frame in g["frames"]], ["CHAR_courier_walk_" + str(i) for i in range(5)])
        self.assertEqual(g["source_fps"], 8)
        self.assertEqual(g["authored_fps"], 8)
        self.assertEqual(p["actual_frame_pts_seconds"], [0, 0.125, 0.25, 0.375, 0.5])
        self.assertEqual([frame["timestamp_seconds"] for frame in g["frames"]], p["actual_frame_pts_seconds"])
        self.assertTrue(all(frame["duration_seconds"] == 0.125 for frame in g["frames"]))
        self.assertAlmostEqual(sum(frame["duration_seconds"] for frame in g["frames"]), 0.625)
        self.assertEqual(g["source_cycle_seconds"], 0.625)
        self.assertEqual(g["cycle_seconds"], 0.625)
        self.assertNotIn("cycle_distance_px", g)

    def test_selected_manifest_is_exact_approved_version_and_has_no_sixth_pose(self):
        self.assertEqual(self.atlas.size, (1600, 500))
        self.assertEqual(digest(ATLAS), APPROVED_ATLAS_SHA)
        self.assertEqual(self.geometry["source_sha256"], APPROVED_ATLAS_SHA)
        self.assertNotIn("CHAR_courier_walk_5", self.manifest["assets"])
        for key in ["CHAR_courier", "CHAR_courier_walk"] + [frame["key"] for frame in self.geometry["frames"]]:
            entry = self.manifest["assets"][key]
            path = ROOT / entry["path"].removeprefix("res://")
            self.assertFalse(entry["ai_generated"])
            self.assertEqual(entry["source_kind"], "user_video_extraction")
            self.assertEqual(entry["style_lock"], "USER_VIDEO_COURIER_20261017")
            self.assertEqual(entry["source_video_sha256"], SOURCE_SHA)
            self.assertEqual(entry["source_frames"], [0, 1, 2, 3, 4])
            self.assertEqual(entry["sha256"], digest(path))
            self.assertEqual(entry["source_sha256"], digest(path))
            self.assertEqual(entry["mode"], "RGBA")
            with Image.open(path) as registered_image:
                self.assertEqual(entry["native_dimensions"], list(registered_image.size))
        for frame in self.geometry["frames"]:
            entry = self.manifest["assets"][frame["key"]]
            self.assertEqual(entry["region"], frame["region"])
            self.assertEqual(entry["source_frame"], frame["source_frame"])
            self.assertEqual(entry["duration_seconds"], 0.125)
        override = self.manifest["user_animation_override"]
        self.assertEqual(override["frame_count"], 5)
        self.assertEqual(override["provenance"], "res://assets/faefever_v2/characters/" + PROVENANCE.name)

    def test_distinct_frame_pixels_match_recorded_extraction(self):
        hashes = []
        for index, frame in enumerate(self.geometry["frames"]):
            self.assertEqual(frame["region"], [index * 320, 0, 320, 500])
            pixel_sha = hashlib.sha256(self.poses[index].tobytes()).hexdigest()
            hashes.append(pixel_sha)
            self.assertEqual(pixel_sha, self.provenance["frames"][index]["rgba_pixels_sha256"])
            self.assertEqual(self.provenance["frames"][index]["source_frame"], index)
        self.assertEqual(len(set(hashes)), 5)

    def test_shared_anchor_preserves_original_pose_padding_and_idle_two(self):
        idle = Image.open(IDLE).convert("RGBA")
        self.assertEqual(idle.tobytes(), self.atlas.crop((640, 0, 960, 500)).tobytes())
        self.assertEqual(self.geometry["idle"]["source_frame"], 2)
        self.assertEqual(self.geometry["idle"]["foot_anchor_px"], [180, 482])
        self.assertEqual(self.geometry["idle"]["reference_height_px"], 463)
        self.assertEqual(self.geometry["crop_source_px"], [170, 135, 490, 635])
        for frame, pose in zip(self.geometry["frames"], self.poses):
            self.assertEqual(frame["foot_anchor_px"], [180, 482])
            self.assertEqual(frame["reference_height_px"], 463)
            self.assertFalse(pose[0, :, 3].any() or pose[-1, :, 3].any())
            self.assertFalse(pose[:, 0, 3].any() or pose[:, -1, 3].any())
            self.assertGreater((pose[:, :, 3] == 0).sum(), 100000)
            self.assertGreater(((pose[:, :, 3] > 0) & (pose[:, :, 3] < 255)).sum(), 3000)
            self.assertGreater(((pose[:, :, :3].min(2) > 185) & (pose[:, :, 3] == 255)).sum(), 12000)

    def test_actual_curl_holes_are_clear_but_black_eyes_and_boots_survive(self):
        self.assertEqual(self.poses[0][188 - 135, 409 - 170, 3], 0)
        self.assertEqual(self.poses[1][184 - 135, 386 - 170, 3], 0)
        self.assertEqual(self.poses[0][289 - 135, 393 - 170].tolist(), [0, 0, 0, 255])
        self.assertEqual(self.poses[1][298 - 135, 380 - 170].tolist(), [3, 0, 0, 255])
        boots = [((292, 562), [37, 32, 8, 255]), ((355, 580), [37, 32, 10, 255]),
                 ((363, 583), [85, 77, 48, 255]), ((389, 584), [86, 78, 49, 255]),
                 ((392, 585), [86, 78, 49, 255])]
        for pose, ((x, y), expected) in zip(self.poses, boots):
            self.assertEqual(pose[y - 135, x - 170].tolist(), expected)
        self.assertEqual([sum(hole["area"] for hole in frame["observed_hair_background_holes_made_transparent"])
                          for frame in self.provenance["frames"]], [442, 188, 0, 0, 0])
        self.assertTrue(all(frame["black_recomposition_foreground_max_abs_error"] <= 1.1 for frame in self.provenance["frames"]))

    def test_spatial_matte_does_not_globally_key_dark_ink_or_boots(self):
        # Analytic alpha unit fixture only, never registered or written as game art.
        raw = np.zeros((500, 320, 3), dtype=np.uint8)
        raw[130:440, 70:270] = [240, 235, 210]
        raw[15:75, 210:260] = [240, 235, 210]
        raw[60:150, 220:245] = [240, 235, 210]
        raw[28:53, 224:243] = 0
        raw[145:153, 230:245] = 0
        raw[430:485, 190:230] = [37, 32, 10]
        raw[210:220, 100:107] = 0
        raw[280:298, 164:172] = 0
        raw[130:440, 68:70] = [60, 59, 52]
        image, stats = EXTRACTOR.matte(Image.fromarray(raw), 0)
        rgba = np.asarray(image)
        self.assertEqual(rgba[40, 235, 3], 0)
        self.assertEqual(rgba[149, 236].tolist(), [0, 0, 0, 255])
        self.assertEqual(rgba[470, 210].tolist(), [37, 32, 10, 255])
        self.assertEqual(rgba[215, 103].tolist(), [0, 0, 0, 255])
        self.assertEqual(rgba[288, 168, 3], 0)
        self.assertEqual(rgba[480, 305, 3], 0)
        self.assertGreater(rgba[200, 69, 3], 0)
        self.assertLess(rgba[200, 69, 3], 255)
        self.assertLessEqual(stats["black_recomposition_foreground_max_abs_error"], 1.1)
        self.assertTrue(np.array_equal(rgba[180:205, 80:100, :3], raw[180:205, 80:100]))
        self.assertTrue((rgba[180:205, 80:100, 3] == 255).all())

    def test_provenance_records_source_and_limits_without_private_paths(self):
        p = self.provenance
        self.assertFalse(p["ai_generated"])
        self.assertFalse(p["original_modified"])
        self.assertEqual(p["source_video_sha256"], SOURCE_SHA)
        self.assertEqual(p["source_dimensions"], [960, 720])
        self.assertEqual(p["source_bytes"], 47603)
        self.assertEqual(p["source_frames"], [0, 1, 2, 3, 4])
        self.assertEqual(p["idle_source_frame"], 2)
        self.assertIn("runtime_review_pending", p["review_status"])
        self.assertTrue(p["limits"])
        for name, expected in p["assets"].items():
            self.assertEqual(digest(ASSETS / name), expected)
        self.assertEqual(p["extractor"]["sha256"], digest(ROOT / "tools/extract_video_courier_20261017.py"))
        public = PROVENANCE.read_text(encoding="utf-8")
        for private in ["xwechat_files", "wxid_", "C:\\Users", "D:/"]:
            self.assertNotIn(private, public)
        self.assertIn(PROVENANCE.name, (ROOT / "export_presets.cfg").read_text(encoding="utf-8"))

    def test_earlier_original_derivatives_are_preserved_byte_for_byte(self):
        old = {"courier_video_20261016.png": "e0f998cc9f34b53fd646f4601013452f15b405a684a5068b4f9c46839d29cd7f",
               "courier_video_idle_20261016.png": "4b82017b9cbebeb74249e3665e0c37fba4d82356e7ee88178d5efb0ec525ba38",
               "courier_video_provenance_20261016.json": "66f749260070391ff77f7a744d9741ed4eee611f587cc2103051b21f7be19e4f"}
        for name, expected in old.items():
            self.assertEqual(digest(ASSETS / name), expected)

    def test_versioned_extractor_rejects_output_overwrite(self):
        with tempfile.TemporaryDirectory(prefix="courier-versioned-unit-") as temporary:
            folder = Path(temporary).resolve()
            self.assertEqual(folder.parent, Path(tempfile.gettempdir()).resolve())
            target = folder / "protected.bin"
            EXTRACTOR.preserve_or_write(target, b"original bytes")
            EXTRACTOR.preserve_or_write(target, b"original bytes")
            with self.assertRaises(ValueError):
                EXTRACTOR.preserve_or_write(target, b"different bytes")
            self.assertEqual(target.read_bytes(), b"original bytes")


if __name__ == "__main__":
    unittest.main()
