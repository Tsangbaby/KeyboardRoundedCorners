"""Source contracts for the supplied xxhook candidate, not device tests."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def control_fields():
    return dict(line.split(": ", 1) for line in (ROOT / "control").read_text().splitlines() if ": " in line)


class ProjectContractTests(unittest.TestCase):
    def test_makefile_initializes_theos_before_tweak_rules(self):
        makefile = (ROOT / "Makefile").read_text()
        self.assertIn("include $(THEOS)/makefiles/common.mk", makefile)
        self.assertLess(makefile.index("include $(THEOS)/makefiles/common.mk"), makefile.index("include $(THEOS_MAKE_PATH)/tweak.mk"))
        self.assertIn("TARGET = iphone:clang:latest:15.0", makefile)
        self.assertIn("ARCHS = arm64 arm64e", makefile)
        self.assertIn("THEOS_PACKAGE_SCHEME = roothide", makefile)
        self.assertIn("TWEAK_NAME = kbrc", makefile)
        self.assertIn("kbrc_FILES = Tweak.xm", makefile)
        self.assertIn("kbrc_FRAMEWORKS = UIKit Foundation", makefile)
        self.assertIn("kbrc_LIBRARIES = substrate", makefile)
        self.assertIn("kbrc_CFLAGS = -fobjc-arc", makefile)
        self.assertTrue((ROOT / "kbrc.plist").is_file())
        self.assertFalse((ROOT / "xxhook.plist").exists())

    def test_hook_validates_the_complete_method_signature_before_install(self):
        source = (ROOT / "Tweak.xm").read_text()
        self.assertIn('#import "KBRCSignature.h"', source)
        self.assertIn("class_getInstanceMethod(cls, selector)", source)
        self.assertIn("method_getNumberOfArguments(method)", source)
        self.assertIn("method_getReturnType(method, returnType, sizeof(returnType))", source)
        for index, name in enumerate(("receiverType", "selectorType", "radiusType")):
            self.assertIn(f"method_getArgumentType(method, {index}, {name}, sizeof({name}))", source)
        self.assertIn("@encode(CGFloat)", source)
        self.assertIn("if (!KBRCSignatureMatches(", source)
        self.assertLess(source.index("if (!KBRCSignatureMatches("), source.index("MSHookMessageEx(cls,"))
        self.assertEqual(source.count("MSHookMessageEx(cls,"), 1)
        self.assertNotIn("method_setImplementation(", source)
        self.assertNotIn("layer.masksToBounds", source)

    def test_missing_class_has_only_one_deferred_retry(self):
        source = (ROOT / "Tweak.xm").read_text()
        constructor = source.split("%ctor {", 1)[1]
        self.assertIn("if (cls)", constructor)
        self.assertIn("dispatch_async(dispatch_get_main_queue()", constructor)
        self.assertEqual(constructor.count("kb_installHook("), 2)
        self.assertNotIn("dispatch_after", source)
        self.assertNotIn("objc_getClassList", source)

    def test_ci_binds_the_candidate_and_builds_both_requested_schemes(self):
        workflow = (ROOT / ".github/workflows/build.yml").read_text()
        self.assertIn("branches: [build/kbrc-1.0.3-packages]", workflow)
        self.assertIn("runs-on: macos-15", workflow)
        self.assertIn("python3 -B scripts/check_host.py --case all", workflow)
        self.assertIn("for scheme in roothide rootless; do", workflow)
        self.assertIn('THEOS_PACKAGE_SCHEME="$scheme"', workflow)
        self.assertIn('plutil -lint kbrc.plist', workflow)
        self.assertIn('DynamicLibraries/kbrc.dylib', workflow)
        self.assertIn("python3 -B scripts/verify_package.py", workflow)
        self.assertIn("SOURCE_COMMIT.txt", workflow)
        self.assertIn("SOURCE_REPOSITORY.txt", workflow)
        self.assertIn("if: always()", workflow)
        self.assertNotIn("make clean || true", workflow)
        self.assertNotIn("inputs.debug", workflow)
        self.assertNotIn("matrix:", workflow)
        self.assertNotIn("simctl", workflow)
        self.assertNotIn("runner.temp", workflow)

    def test_runtime_and_filter_bytes_match_the_device_accepted_baseline(self):
        import subprocess
        base = "71c6b8597f0646fb57d673293ad832d8de69f3e6"
        for path in ("Tweak.xm", "KBRCSignature.h", "scripts/check_host.py", "tests/signature_test.c"):
            self.assertEqual((ROOT / path).read_bytes(), subprocess.check_output(["git", "show", f"{base}:{path}"], cwd=ROOT))
        self.assertEqual((ROOT / "kbrc.plist").read_bytes(), subprocess.check_output(["git", "show", f"{base}:xxhook.plist"], cwd=ROOT))

    def test_ci_lipo_uses_input_before_verify_arch_and_preserves_original(self):
        import shlex
        workflow = (ROOT / ".github/workflows/build.yml").read_text()
        command = next(line.strip() for line in workflow.splitlines() if line.strip().startswith("xcrun lipo -verify_arch") or ('xcrun lipo "$dylib" -verify_arch' in line))
        self.assertEqual(shlex.split(command), ["xcrun", "lipo", "$dylib", "-verify_arch", "arm64", "arm64e"])
        self.assertLess(workflow.index('cp "$package" ci-artifacts/'), workflow.index('python3 -B scripts/verify_package.py "$package"'))

    def test_requested_package_identity_and_ios_floor(self):
        fields = control_fields()
        self.assertEqual(fields["Package"], "com.tsangbaby.kbrc")
        self.assertEqual(fields["Author"], "Tsangbaby")
        self.assertEqual(fields["Maintainer"], "Tsangbaby")
        self.assertEqual(fields["Version"], "1.0.3")
        self.assertEqual(fields["Description"], "调整系统键盘按键圆角，让键盘外观更加圆润、简洁。需要 iOS 15 或更高版本。")
        self.assertNotIn("Icon", fields)
        self.assertIn("firmware (>= 15.0)", fields["Depends"])
        self.assertIn("mobilesubstrate (>= 0.9.5000)", fields["Depends"])


if __name__ == "__main__":
    unittest.main()
