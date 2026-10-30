# Keyboard Rounded Corners — supplied xxhook source

本分支以本次上传的 `xxhook_1.0-1_源码.zip` 为功能基线，不使用仓库旧版的键帽视图裁剪实现。原有 `main` 保留不动。

- 包标识：`com.tsangbaby.kbrc`
- 作者 / 维护者：`Tsangbaby`
- Debian 版本：`1.0-1`（保留上传源码版本）
- 最低部署版本及安装依赖：iOS **15.0**
- 本次构建目标：**RootHide**，`arm64 + arm64e`
- 动态库 / 注入配置：`xxhook.dylib` / `xxhook.plist`

## 功能与边界

唯一的功能 Hook 是 `UIKBRenderGeometry` 的 `setRoundRectRadius:`：忽略系统传入值，将 `10.0 pt` 交给原实现。保留 `Bundles = com.apple.UIKit` 注入条件；没有设置页、动画、键盘内容读取、联网或每次输入日志。

修正 Theos 初始化顺序，编译 SDK 改为所选 Xcode 可用 SDK，独立保留 iOS 15.0 部署下限。安装 Hook 前检查目标类、方法、参数数量、返回类型和每个参数类型；拒绝不兼容 ABI。原实现指针缺失时不调用空指针。仅当启动时目标类未找到，下一次主队列执行一次补试，不进行轮询或全类扫描。

日志仅用于报告安装阶段的类 / 方法 / ABI 不兼容，没有键入内容、逐键日志或文件诊断采集器。这是功能验证包，不是诊断日志包。

`UIKBRenderGeometry` 是私有接口。iOS 15+ 是最低系统要求，不代表已经验证所有更高系统；目标设备是否实际经过此 setter、哪些键盘样式可见变化，必须实机测试。构建和包校验不等于实机生效。

## 本地检查

```sh
python3 -B -m unittest discover -s tests -p 'test_*.py' -v
python3 -B scripts/check_host.py --case all
```

宿主测试执行实际转发函数体及实际 ABI 比较器。测试中的接收者和原函数是 C 测试边界，不是 iOS Objective-C 运行时或真实键盘。

## 构建 RootHide

准备带 RootHide 支持的 Theos、Apple iPhoneOS 工具链和签名 / Debian 打包工具后：

```sh
export THEOS=/path/to/roothide-theos
make clean THEOS_PACKAGE_SCHEME=roothide
make package THEOS_PACKAGE_SCHEME=roothide FINALPACKAGE=1 INSTALL=0
```

产物为 `packages/com.tsangbaby.kbrc_1.0-1_iphoneos-arm64e.deb`。

本分支 `.github/workflows/build.yml` 只构建 RootHide，在 `build/xxhook-ios15-roothide` 推送时触发。固定 Theos 和 Actions 提交，记录实际 Apple 编译器 / SDK、源码提交、仓库和运行编号，并上传原始 `.deb`、SHA-256、包校验报告与完整构建日志。不发布正式 Release。

## 安装与实机测试

1. 确认是 iOS 15+ 的 **RootHide** 环境，并允许插件注入目标 App。这个包不是普通 Rootless 通用包。
2. 先停用或卸载其他系统键盘圆角 / 主题插件，避免同一渲染链路互相覆盖。若有原包 `com.wkk.kbhook`，不要与本包同时启用。
3. 用包管理器安装原始 `.deb`，完成要求的用户空间重启 / 注销后，**完全退出并重新打开待测 App**。只重启 SpringBoard 不会替所有 App 重新加载动态库。
4. 在备忘录以及另一个常用 App 打开系统键盘，比较字母 / 中文、数字符号、深浅色和横竖屏切换；留意圆角变化、按键弹出和候选栏是否正常。
5. 没有变化属于待定位结果，不能据此扩大 Hook 范围或宣称整个 iOS 版本不兼容。

**版本注意：** 仓库旧 `main` 为 `1.0.2`，按 Debian 比较规则高于本次保留的 `1.0-1`。若设备装过同标识旧版，需要在包管理器选择本地重装 / 降级，或先卸载旧版；它不会被视作常规升级。

## 来源

原附件逐文件导入提交：`69d7d63665af6244e1006750935027244ed29671`。详见 [来源与验证边界](docs/SOURCE_PROVENANCE.md)。附件声称来自逆向还原，但未提供原始二进制及分析报告，不能证明与原插件完全等价。
