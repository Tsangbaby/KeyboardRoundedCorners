# Keyboard Rounded Corners

调整系统键盘按键圆角，让键盘外观更加圆润、简洁。需要 iOS 15 或更高版本。

- 当前构建版本：**1.0.3**
- 包标识：`com.tsangbaby.kbrc`
- 作者 / 维护者：**Tsangbaby**
- 最低系统要求：**iOS 15.0**
- 安装包：**Rootless / RootHide**，请按越狱环境选择，不可混装。
- 动态库 / 注入配置：`kbrc.dylib` / `kbrc.plist`
- 两种包均编译 `arm64 + arm64e`，Debian 架构标签由所选打包方案决定。

## 功能

将系统键盘渲染几何的圆角参数固定为 **10pt**。无设置页，安装并重新加载插件后使用；不读取键入内容、不联网、不进行逐键日志或文件诊断采集。

功能入口是 `UIKBRenderGeometry` 的 `setRoundRectRadius:`。保留 `Bundles = com.apple.UIKit` 注入条件，在安装 Hook 前检查类、方法及完整参数类型；未知接口会跳过。原实现指针为空时不调用。仅在启动时类尚未找到的情况下，下一次主队列执行一次补试，没有轮询或全类扫描。

`kbrc` 是构建产物名称，不是被 Hook 的系统类名。1.0.3 同步修改 Theos 目标名及 plist 名，动态库安装标识由相应方案自动生成；**功能源文件、10pt 参数、注入过滤内容与已实机通过的基线保持一致**。

## 安装与测试

- **Rootless**：选择 `com.tsangbaby.kbrc_1.0.3_iphoneos-arm64.deb`，文件位于 `/var/jb/Library/MobileSubstrate/DynamicLibraries/`。
- **RootHide**：选择 `com.tsangbaby.kbrc_1.0.3_iphoneos-arm64e.deb`，包内文件位于 `Library/MobileSubstrate/DynamicLibraries/`，动态库使用 `.jbroot` 路径。
- 使用包管理器升级后，完成其要求的注销 / 用户空间重启，并**完全退出、重新打开待测 App**。只重启 SpringBoard 不会让所有已运行 App 重新加载插件。
- 停用其他系统键盘圆角 / 主题插件。若装有来源不同的 `com.wkk.kbhook`，不要同时启用。
- 在备忘录和另一个常用 App 检查系统键盘的中文 / 字母、数字符号、深浅色、横竖屏以及按键弹出和候选栏。

本次沿用相同包标识。Debian 版本比较已验证：`1.0.3` 高于之前的 `1.0-1` 和仓库旧实现的 `1.0.2`，无需按旧说明降级。正常包管理器升级会依据旧包文件清单移除被替换的 `xxhook.dylib / xxhook.plist`；不要手工同时保留两套文件。

## 验证状态

- 基线 `71c6b8597f0646fb57d673293ad832d8de69f3e6` 对应的 RootHide 包已由用户报告实机测试通过，现为本轮构建基线。
- 1.0.3 的本地检查执行实际转发函数体和实际 ABI 比较器，并校验运行时代码 / 重命名过滤器与基线的字节一致性。
- 云端针对同一源码提交分别执行 iPhoneOS 编译、链接、签名和两种包的内容校验，保留原始 `.deb`、源码身份、SHA-256 与完整日志。
- **1.0.3 的改名后加载、升级过程及 Rootless 实机效果仍待设备验证。** 继承的是基线功能证据，不是所有方案或系统版本的实机验收。

`UIKBRenderGeometry` 属于私有接口。iOS 15+ 表示最低要求，不代表所有更高系统或第三方自绘键盘都已验证。

## 构建

需要支持这两种方案的 Theos、Apple iPhoneOS 工具链，以及 GNU make、Debian 打包和签名工具。当前默认方案为 RootHide；命令行参数可显式覆盖。

```sh
export THEOS=/path/to/roothide-theos

# Rootless
make clean THEOS_PACKAGE_SCHEME=rootless
make package THEOS_PACKAGE_SCHEME=rootless FINALPACKAGE=1 INSTALL=0

# RootHide
make clean THEOS_PACKAGE_SCHEME=roothide
make package THEOS_PACKAGE_SCHEME=roothide FINALPACKAGE=1 INSTALL=0
```

版本读取自 `control`，产物位于 `packages/`。部署版本为 iOS 15.0；编译 SDK 与最低系统版本是不同概念。

```sh
python3 -B -m unittest discover -s tests -p 'test_*.py' -v
python3 -B scripts/check_host.py --case all
python3 -B scripts/verify_package.py packages/com.tsangbaby.kbrc_1.0.3_iphoneos-arm64.deb --scheme rootless
python3 -B scripts/verify_package.py packages/com.tsangbaby.kbrc_1.0.3_iphoneos-arm64e.deb --scheme roothide
```

`.github/workflows/build.yml` 在 `build/kbrc-1.0.3-packages` 推送时构建两种方案，固定 Theos 和 Actions 提交，记录实际 Apple 编译器 / SDK。此工作流仅生成验证包，不创建标签或正式 Release。

## 1.0.3 更新

- 动态库及注入配置统一命名为 `kbrc.dylib / kbrc.plist`。
- 更新中文包描述，移除远程 Icon 字段。
- 增加 Rootless 构建交付，保留 RootHide 构建。
- 保持已通过实机测试的圆角逻辑、注入范围和安全检查不变。

## 来源

以用户提供的 `xxhook_1.0-1_源码.zip` 为源头，未使用仓库更早的键帽视图裁剪实现。原附件逐文件导入提交为 `69d7d63665af6244e1006750935027244ed29671`。原二进制及逆向分析报告未随附件提供，因此不宣称与原插件完全等价。详见 [来源与验证边界](docs/SOURCE_PROVENANCE.md)。
