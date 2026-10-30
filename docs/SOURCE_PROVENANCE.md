# Supplied-source provenance and protected predecessor

- User attachment: `xxhook_1.0-1_源码.zip`
- Archive SHA-256: `001b0b29bb6f6277e7ca464ff2a8007ef54be8521995f968e560fa541a5db122`
- Archive member count: 7; CRC and traversal / duplicate / special-file checks passed before extraction.
- Exact archive-source import commit: `69d7d63665af6244e1006750935027244ed29671`.
- Intended source and CI repository: `https://github.com/Tsangbaby/KeyboardRoundedCorners`.
- Candidate branch: `build/xxhook-ios15-roothide`.
- Protected existing main: `0a3e33e4e4f88d75936f9d5d6ffda345e35597af`.

The import commit preserves all seven supplied file bytes at repository-root-relative paths. It replaces the previous candidate-tree implementation; the predecessor remains intact on main and in Git history. The old `KBRCKeyGeometry.h`, `kbrc.plist` and keycap-view tests are predecessor-only files, not inputs to this source. The current active compile graph is `Tweak.xm`, including `KBRCSignature.h`, with `xxhook.plist` staged by the `xxhook` Theos target.

The archive's claimed original package ID is `com.wkk.kbhook`, version `1.0-1`, author `wkk`. Its documentation references an original binary, reverse-engineering report and helper tool that are absent. These claims are historical input, not independently verified binary provenance. No original `.deb` or `.dylib` was included.

Authorized adaptation changes the package ID, author / maintainer and iOS installation floor; fixes Theos bootstrap / SDK selection; adds a narrow method-signature gate, null-original safety and one missing-class startup retry. It retains the single setter hook and 10-point forwarding behavior. No view clipping, additional keyboard hooks, preference UI or per-input diagnostics are added.

Evidence levels remain separate: source contracts; host execution of source-bound C seams; real iPhoneOS arm64 / arm64e compilation and packaging; independent verification of the downloaded original package; and pending handset acceptance. No host or CI result certifies visible keyboard behavior.
