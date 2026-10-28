#!/usr/bin/env python3
"""Static guardrails for the individual-keycap-only hook target."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
source = (root / "Tweak.xm").read_text()

assert 'strcmp(name, "UIKBKeyView") == 0' in source
assert 'strcmp(name, "UIKBContainerKeyView") == 0' in source
assert 'strcmp(className, "UIKBKeyView") == 0' in source
assert 'strcmp(className, "UIKBContainerKeyView") == 0' in source
assert '"TUISeparatedKBKeyView"' not in source, "do not override its native state corners"
assert 'KBRCKeyCapCornerRadiusForSize(' in source
assert 'layer.masksToBounds = YES' in source
assert 'KBRCNameLooksLikeKeyboardBackground' not in source
assert 'kKBRCMinScreenWidthRatio' not in source
assert 'kKBRCMinHeight' not in source

# The actual strict allowlist must not match keyboard backdrops or helpers.
block = re.search(r'static BOOL KBRCNameLooksLikeKeyboardKey\(.*?\n\}', source, re.S)
assert block, "keycap class allowlist function missing"
assert 'UIKBBackdropView' not in block.group(0)
assert 'UIKBBackgroundView' not in block.group(0)

print("PASS: keycap-only class allowlist and source contract")
