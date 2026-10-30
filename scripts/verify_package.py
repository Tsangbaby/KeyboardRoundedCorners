#!/usr/bin/env python3
"""Read-only verification of this project's original RootHide .deb."""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import io
import json
import plistlib
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[1]


def fields(text):
    return dict(line.split(": ", 1) for line in text.splitlines() if ": " in line and not line.startswith(" "))


def canonical(name):
    path = PurePosixPath(name)
    assert not path.is_absolute() and ".." not in path.parts, name
    return str(path)


def inspect_tar(data):
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        members = archive.getmembers()
        paths = [canonical(member.name) for member in members]
        assert len(paths) == len(set(paths)), paths
        assert len(members) < 200 and sum(m.size for m in members) < 20 * 1024 * 1024
        result = {}
        for member, path in zip(members, paths):
            assert member.isdir() or member.isfile(), (path, "unexpected link or special file")
            if member.isfile():
                stream = archive.extractfile(member)
                assert stream is not None
                result[path] = {"mode": member.mode, "size": member.size, "data": stream.read(),
                                "uid": member.uid, "gid": member.gid, "uname": member.uname, "gname": member.gname}
        return result


def verify(package):
    expected = fields((ROOT / "control").read_text())
    actual = fields(subprocess.check_output(["dpkg-deb", "-f", str(package)], text=True))
    for key in ("Package", "Version", "Author", "Maintainer", "Depends"):
        assert actual[key] == expected[key], (key, actual.get(key), expected[key])
    assert actual["Architecture"] == "iphoneos-arm64e", actual
    assert "firmware (>= 15.0)" in actual["Depends"]
    payload = inspect_tar(subprocess.check_output(["dpkg-deb", "--fsys-tarfile", str(package)]))
    control = inspect_tar(subprocess.check_output(["dpkg-deb", "--ctrl-tarfile", str(package)]))
    dylib = "Library/MobileSubstrate/DynamicLibraries/xxhook.dylib"
    filter_path = "Library/MobileSubstrate/DynamicLibraries/xxhook.plist"
    assert set(payload) == {dylib, filter_path}, list(payload)
    assert not any(path.startswith("var/jb/") for path in payload)
    filter_value = plistlib.loads(payload[filter_path]["data"])
    assert filter_value == {"Filter": {"Bundles": ["com.apple.UIKit"]}}, filter_value
    assert payload[dylib]["data"][:4] in (b"\xca\xfe\xba\xbe", b"\xca\xfe\xba\xbf"), "expected universal Mach-O"
    for script in ("preinst", "postinst", "prerm", "postrm", "extrainst_"):
        if script in control:
            assert control[script]["mode"] == 0o755, (script, control[script]["mode"])
            assert control[script]["data"].startswith(b"#!/"), script
    data = package.read_bytes()
    return {"package_file": str(package), "scheme": "roothide", "size": len(data),
            "sha256": hashlib.sha256(data).hexdigest(), "metadata": actual,
            "payload": {path: {k: v for k, v in value.items() if k != "data"} for path, value in payload.items()},
            "control_members": {path: {k: v for k, v in value.items() if k != "data"} for path, value in control.items()},
            "filter": filter_value, "device_tested": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    args = parser.parse_args()
    print(json.dumps(verify(args.package), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
