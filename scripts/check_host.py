#!/usr/bin/env python3
"""Execute the real forwarding body and ABI comparator on a host, not iOS."""
from pathlib import Path
import argparse
import os
import re
import resource
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def function_body(source, signature):
    assert source.count(signature) == 1, signature
    start = source.index(signature)
    opening = source.index("{", start)
    depth = 1
    cursor = opening + 1
    while depth:
        depth += (source[cursor] == "{") - (source[cursor] == "}")
        cursor += 1
    return source[start:cursor]


def no_core_dump():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def run_c(text):
    with tempfile.TemporaryDirectory(prefix="kbrc-host-") as directory:
        root = Path(directory)
        source, binary = root / "fixture.c", root / "fixture"
        source.write_text(text)
        command = [os.environ.get("CC", "cc"), "-std=c11", "-Wall", "-Wextra", "-Werror", "-Wno-unused-parameter", "-I", str(ROOT), str(source), "-o", str(binary)]
        subprocess.run(command, check=True)
        result = subprocess.run([str(binary)], text=True, capture_output=True, preexec_fn=no_core_dump)
        print(result.stdout, end="")
        print(result.stderr, end="")
        if result.returncode:
            raise SystemExit(f"HOST_EXECUTION_FAILED status={result.returncode}; compilation had succeeded")


def forwarding():
    source = (ROOT / "Tweak.xm").read_text()
    wrapper = function_body(source, "static void kb_setRoundRectRadius(")
    constant_match = re.search(r"^#define KB_CORNER_RADIUS\s+[^\n]+", source, re.M)
    original_match = re.search(r"^static void \(\*orig_setRoundRectRadius\)\(id, SEL, CGFloat\);", source, re.M)
    assert constant_match is not None and original_match is not None
    constant, original = constant_match.group(0), original_match.group(0)
    run_c("""
#include <assert.h>
#include <math.h>
#include <stdio.h>
typedef void *id;
typedef void *SEL;
typedef double CGFloat;
""" + constant + "\n" + original + "\n" + wrapper + r'''
static int calls;
static id seen_self;
static SEL seen_selector;
static double seen_radius;
static void record_original(id object, SEL selector, CGFloat radius) {
    ++calls;
    seen_self = object;
    seen_selector = selector;
    seen_radius = radius;
}
int main(void) {
    id object = (void *)0x1234;
    SEL selector = (void *)0x5678;
    orig_setRoundRectRadius = NULL;
    kb_setRoundRectRadius(object, selector, 9.0);
    assert(calls == 0);
    orig_setRoundRectRadius = record_original;
    const double inputs[] = {-10.0, 0.0, 1.0, 10.0, 100.0, NAN, INFINITY};
    const unsigned count = sizeof(inputs) / sizeof(inputs[0]);
    for (unsigned i = 0; i < count; ++i) {
        kb_setRoundRectRadius(object, selector, inputs[i]);
        assert(calls == (int)i + 1);
        assert(seen_self == object && seen_selector == selector);
        assert(seen_radius == 10.0);
    }
    printf("KBRC_FORWARDING_PASS calls=%u null_original=SAFE NOT_OBJC_DISPATCH\n", count);
    return 0;
}
''')


def signature():
    run_c((ROOT / "tests/signature_test.c").read_text())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=("forwarding", "signature", "all"), default="all")
    args = parser.parse_args()
    if args.case in ("forwarding", "all"):
        forwarding()
    if args.case in ("signature", "all"):
        signature()


if __name__ == "__main__":
    main()
