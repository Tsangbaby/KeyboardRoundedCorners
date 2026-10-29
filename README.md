# xxhook

「系统键盘圆角」——由 `com.wkk.kbhook_1.0-1_iphoneos-arm64e.deb` 逆向还原的 Theos 工程。

原始二进制、原始 control、原始 filter plist 留档在 `../原始二进制/`，
逐指令分析见 `../逆向分析报告.md`。

## 目录

```
xxhook/
├── Tweak.xm                      ← 全部逻辑（20 行，对应原始 68 字节机器码）
├── Makefile                      ← 已按原始 load commands 对齐
├── control                       ← 复用原包元数据
├── xxhook.plist                  ← 注入过滤器（Bundles = com.apple.UIKit）
└── reference/UIKBRenderGeometry.h  ← 私有类参考声明，不参与编译
```

## 编译

```bash
export THEOS=~/theos          # 或你把 theos 放哪了
cd xxhook
make package
```

产物：`.theos/obj/debug/xxhook.dylib`（或 `packages/com.wkk.kbhook_1.0-1_*.deb`）。

装到设备：

```bash
make install                  # 需要 THEOS_DEVICE_IP
# 或手工
scp .theos/obj/debug/xxhook.dylib root@<ip>:/var/jb/Library/MobileSubstrate/DynamicLibraries/
```

## 三种引导方式怎么选

`Makefile` 里 `THEOS_PACKAGE_SCHEME` 一行决定产物形态：

| 值 | 适用 | install_name |
|---|---|---|
| `roothide` | roothide bootstrap（**原包就是这个**） | `@loader_path/.jbroot/...` |
| `rootless` | Dopamine / palera1n rootless | `@loader_path/../../usr/lib/...` |
| 删除该行 | rootful（unc0ver / checkra1n / 无根隐藏） | `/Library/MobileSubstrate/...` |

装错环境的表现是 dylib 加载失败（Substrate 日志报找不到 `libsubstrate.dylib`），不会崩系统。

## 改圆角大小

`Tweak.xm` 顶部：

```objc
#define KB_CORNER_RADIUS 10.0
```

改完 `make package` 重装即可。这只是把原来那条 `fmov d0, #10.0` 换个立即数，不改变逻辑。

## 注意（改代码前先读）

1. `xxhook.plist` 的 `Bundles = com.apple.UIKit` 是**故意**这么宽的——App 内键盘跑在 App 自己的进程里，
   收窄到 SpringBoard 会让大部分场景失效。别"优化"它。
2. 换 iOS 大版本后，先跑一次 `python ../tools/inspect_deb.py <你的包> --dump`，
   确认 `imports(bind)` 仍然只有 `_MSHookMessageEx` / `_objc_getClass` 两项。
3. `UIKBRenderGeometry` 是私有类，Apple 随时可能改。`Tweak.xm` 里已加 `cls` 判空 + 日志，
   真机上看 Console 的 `[xxhook]` 前缀即可判断是否失效。
