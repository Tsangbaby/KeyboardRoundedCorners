"""Execute the actual scheme-layout contract used by the package verifier."""
from pathlib import Path
import importlib.util
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("kbrc_package_verifier", ROOT / "scripts/verify_package.py")
assert SPEC is not None and SPEC.loader is not None
VERIFIER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFIER)


class PackageLayoutTests(unittest.TestCase):
    def test_exact_scheme_layouts(self):
        layout = getattr(VERIFIER, "package_layout", None)
        self.assertTrue(callable(layout), "verifier must select the scheme explicitly")
        assert callable(layout)
        expected = {
            "roothide": ("iphoneos-arm64e", "Library/MobileSubstrate/DynamicLibraries/kbrc.dylib", "Library/MobileSubstrate/DynamicLibraries/kbrc.plist"),
            "rootless": ("iphoneos-arm64", "var/jb/Library/MobileSubstrate/DynamicLibraries/kbrc.dylib", "var/jb/Library/MobileSubstrate/DynamicLibraries/kbrc.plist"),
        }
        for scheme, want in expected.items():
            with self.subTest(scheme=scheme):
                self.assertEqual(layout(scheme), want)
        with self.assertRaises(ValueError):
            layout("rootful")


if __name__ == "__main__":
    unittest.main()
