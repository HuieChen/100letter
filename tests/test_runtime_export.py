import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

SPEC = importlib.util.spec_from_file_location('runtime_export', Path(__file__).resolve().parents[1] / 'tools/complete_runtime_export.py')
EXPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EXPORT)


class RuntimeExportTests(unittest.TestCase):
    def test_raw_bytes_are_added_and_compiled_entries_preserved(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'assets').mkdir()
            (root / 'assets/water.png').write_bytes(b'original-water-bytes')
            (root / 'export_presets.cfg').write_text('include_filter="assets/*.png"\nexclude_filter="work/*"\n')
            archive = root / 'export.zip'
            with zipfile.ZipFile(archive, 'w') as zipped:
                zipped.writestr('.godot/imported/water.ctex', b'imported')
            result = EXPORT.complete(root, archive, root / 'stage', root / 'inventory.json')
            self.assertEqual(result['total_entries'], 2)
            self.assertEqual(result['raw_count'], 1)
            self.assertEqual((root / 'stage/assets/water.png').read_bytes(), b'original-water-bytes')
            self.assertEqual((root / 'stage/.godot/imported/water.ctex').read_bytes(), b'imported')

    def test_private_paths_and_traversal_are_rejected(self):
        for path in ('../secret', 'C:/secret', '/secret', 'work/probe.gd', 'specification/input.png',
                     'assets/locked_user/source.png', 'assets/display_user/unapproved.png', 'clip.mp4'):
            with self.subTest(path=path), self.assertRaises(ValueError):
                EXPORT.safe_path(path)
        self.assertEqual(EXPORT.safe_path(EXPORT.COVER), EXPORT.COVER)

    def test_missing_literal_and_changed_export_fail(self):
        for missing in (True, False):
            with self.subTest(missing=missing), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                (root / 'export_presets.cfg').write_text('include_filter="required.txt"\nexclude_filter=""\n')
                if not missing:
                    (root / 'required.txt').write_bytes(b'original')
                archive = root / 'export.zip'
                with zipfile.ZipFile(archive, 'w') as zipped:
                    zipped.writestr('required.txt', b'different')
                with self.assertRaises(ValueError):
                    EXPORT.complete(root, archive, root / 'stage', root / 'inventory.json')


if __name__ == '__main__':
    unittest.main()
