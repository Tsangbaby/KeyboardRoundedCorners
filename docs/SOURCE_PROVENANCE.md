# Supplied-source provenance and device-accepted baseline

- User attachment: `xxhook_1.0-1_源码.zip`
- Archive SHA-256: `001b0b29bb6f6277e7ca464ff2a8007ef54be8521995f968e560fa541a5db122`
- Archive member count: 7; CRC and traversal / duplicate / special-file checks passed before extraction.
- Exact archive-source import commit: `69d7d63665af6244e1006750935027244ed29671`.
- Intended source and CI repository: `https://github.com/Tsangbaby/KeyboardRoundedCorners`.
- Original test branch (retired after promotion): `build/xxhook-ios15-roothide`.
- Device-accepted baseline, promoted to main: `71c6b8597f0646fb57d673293ad832d8de69f3e6`.
- Rejected predecessor (historical only): `0a3e33e4e4f88d75936f9d5d6ffda345e35597af`.
- Current 1.0.3 package candidate: `build/kbrc-1.0.3-packages`.

The import commit preserves all seven supplied file bytes at repository-root-relative paths. The rejected view-clipping implementation remains only in Git history, not active main. Its old `KBRCKeyGeometry.h` and keycap-view tests are not compiled inputs. In 1.0.3 the active compile graph is the unchanged `Tweak.xm`, including unchanged `KBRCSignature.h`, with `kbrc.plist` staged by the renamed `kbrc` Theos target. The current filter is byte-identical to the accepted baseline's `xxhook.plist`; it is not the old view-clipping implementation merely because a filename is reused.

The archive's claimed original package ID is `com.wkk.kbhook`, version `1.0-1`, author `wkk`. Its documentation references an original binary, reverse-engineering report and helper tool that are absent. These claims are historical input, not independently verified binary provenance. No original `.deb` or `.dylib` was included.

Authorized adaptation changes the package ID, author / maintainer and iOS installation floor; fixes Theos bootstrap / SDK selection; adds a narrow method-signature gate, null-original safety and one missing-class startup retry. It retains the single setter hook and 10-point forwarding behavior. No view clipping, additional keyboard hooks, preference UI or per-input diagnostics are added.

The user reported the baseline RootHide package passed handset testing before it was promoted to main. Its package SHA-256 was `993c96be8f02d1e2b671db4b00ddeeb6c6dd576149eb2bdaac5cb88d9480178a`, built in run `40977476783`. The report did not establish an all-OS or all-scheme device matrix.

Version 1.0.3 changes package metadata, output names, documentation and dual-scheme build / verification only. The runtime source and signature helper are protected byte-for-byte against the accepted baseline. Evidence levels remain separate: source contracts; host execution of source-bound C seams; real iPhoneOS arm64 / arm64e compilation and packaging; independent verification of downloaded originals; inherited baseline device acceptance; and pending 1.0.3 renamed / Rootless handset acceptance. No host or CI result certifies visible keyboard behavior.
