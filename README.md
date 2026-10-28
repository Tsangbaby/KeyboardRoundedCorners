# Keyboard Rounded Corners

给 iOS 系统键盘里的**每个独立键位 / 键帽**加连续圆角，例如字母键、数字键、功能键和空格键。目标效果是每个键帽各自圆角，不是把整块键盘外框裁成圆角。目标系统 iOS 15 及以上，实际类名与渲染方式仍需在目标设备验证。

- 包名：`com.tsangbaby.kbrc`
- 作者 / 维护者：Tsangbaby
- 产物：`kbrc.dylib`（arm64 + arm64e）

---

## 一、它是怎么做的

```text
注入    kbrc.plist → Bundles = com.apple.UIKit
发现    注入进程里只匹配 UIKBKeyView 与 UIKBContainerKeyView 两个键帽类
挂载    UIKBKeyView 自己实现的 layoutSubviews；容器类自己实现的 prepareForDisplay
施加    原实现完成后，按键帽 bounds 短边的 25% 设置连续圆角，最高 14 pt，并裁剪键帽内容
```

`Bundles = com.apple.UIKit` 是动态库注入过滤条件；它不是 `UIKeyboardImpl` 的类存在检查，也不是把 UIKit.framework 链接进 tweak。公开的系统键盘主题插件 [OledKeyboard](https://github.com/dayanch96/OledKeyboard/blob/main/OledKeyboard.plist) 也使用这个 Bundle filter。其他键盘 tweak 的目标可能不同，例如 [FlicksForAll](https://github.com/Treeki/FlicksForAll/blob/master/flickplus.plist) 选择 `com.apple.TextInput`；因此不把某一个过滤器概括成所有插件都相同。

注入之后，本 tweak 仍只对单键帽类做运行时 Hook，而不是对键盘底板 `UIKBBackdropView` / `UIKBBackgroundView` 做圆角。`UIKBKeyView` / `UIKBContainerKeyView` 是 UIKit 私有实现；iOS 18 的 TextInputUI 键帽基类继承自 `UIKBContainerKeyView`。类名、宿主进程、键帽渲染层级和生命周期不是 Apple 对第三方承诺的公共 API，版本间可能变化。

圆角半径随键帽短边缩放：`min(短边 × 0.25, 14 pt)`。对示例图中约 33×42 pt 的字母键，得到约 8.25 pt；空格键宽而高较小，仍按其短边计算。

系统可能把键帽绘制到 `UIKBKeyView` 的 layer 内容或子 layer 中。代码在目标 view 的 layer 上设置 `cornerRadius` 并开启 `masksToBounds`，用于裁出独立键帽形状；如果某系统把阴影绘制在同一 view 边界之外，裁剪可能影响阴影表现，需要设备测试。

---

## 二、构建

需要 [Theos](https://github.com/theos/theos)。没有 Mac 就用仓库里的 GitHub Actions。

```bash
export THEOS=~/theos
make package FINALPACKAGE=1
# 产物：packages/com.tsangbaby.kbrc_1.0.2_*.deb
```

本仓库的 GitHub Actions 会在云端 macOS 上固定使用官方 [roothide/theos](https://github.com/roothide/theos) 构建 roothide 包。

包形态在 `Makefile` 第一行切换（默认 roothide）：

| 你的环境 | 设置 |
|---|---|
| roothide bootstrap | `THEOS_PACKAGE_SCHEME = roothide`（默认） |
| Dopamine / palera1n rootless | `THEOS_PACKAGE_SCHEME = rootless` |
| 传统 rootful | 这一行留空 |

---

## 三、安装与生效

```bash
dpkg -i com.tsangbaby.kbrc_1.0.2_*.deb
killall -9 SpringBoard
```

安装后需要重启实际输入的目标 App，使键盘进程重新加载 tweak。成功时应看到**每个独立键帽**都有自己的圆角，空格键、字母键、数字键和功能键分别保持各自形状；不是整块键盘背景只出现一个大外框圆角。图片示例中的键帽圆角比例约为短边的 1/4，代码上限为 14 pt。

---

## 四、没生效怎么查（3 分钟）

```bash
make clean && make package FINALPACKAGE=1 DEBUG=1
# 装包后
log stream --predicate 'eventMessage CONTAINS "[kbrc]"' --style compact
```

调试构建会把运行时类列表、键帽命中类、实际挂钩方法和半径写入统一的 `[kbrc]` 日志。重点查看：

| 日志 | 含义 | 判断 |
|---|---|---|
| `keyboard-class: UIKBKeyView` | 当前进程中注册了标准键帽类 | 无此行需确认该进程/系统是否使用此实现 |
| `hooked keycap -[UIKBKeyView layoutSubviews]` 或 `hooked keycap -[UIKBContainerKeyView prepareForDisplay]` | 实际挂钩的键帽布局入口 | 应至少看到一个 `hooked keycap` |
| `rounded keycap UIKBKeyView 33.0x42.0 radius=8.3` | 已对该键帽 view 的 layer 应用圆角 | 应能在画面上看到多个独立键帽各自圆角 |

若没有 `rounded keycap`，可能是注入筛选未命中，或目标系统没有使用 allowlist 中的类；若日志显示已处理但外观没变，系统可能通过独立渲染 layer 绘制键帽背景，需要采集目标设备的类/视图层级后再适配，不应再改键盘外框类。

---

## 五、可调参数

| 常量 | 默认 | 作用 |
|---|---|---|
| `KBRCKeyCapCornerRadiusForSize` 的比例 | `0.25` | 键帽短边的四分之一 |
| `KBRCKeyCapCornerRadiusForSize` 的上限 | `14.0 pt` | 防止大键位产生过度圆角 |
| `KBRCKeyCapCornerRadiusForSize` 的最小短边 | `4.0 pt` | 跳过零尺寸或非键帽尺寸 |

几何函数位于 `KBRCKeyGeometry.h`，有宿主侧单元测试覆盖；源代码类名和真实键帽渲染仍须在设备上验证。

---

## 六、已知不确定项（请当成待验证清单，不是免责声明）

1. **私有类与渲染时机**：代码支持 UIKitCore 的 `UIKBKeyView` 与 `UIKBContainerKeyView`；部分较新 TextInputUI 键帽基类继承自这些 UIKit 类。它们都不是 Apple 的公共 API。目标 iOS 版本可能改用其他类或将键帽绘制到其他 layer。
2. **键帽 layer 结构**：目前对键帽 view 的主 layer 设置 `cornerRadius` 和 `masksToBounds`。若系统把阴影放在同一 layer 的边界外，阴影可能被裁掉；若键帽面是外部 atlas，日志会显示已处理但视觉可能不变。
3. **键盘状态**：键帽重用、按下/弹起、切换语言、候选栏、横竖屏和深色模式都可能重新生成或重置渲染，需要在目标设备逐项测试。
4. **第三方键盘**：第三方键盘自绘，通常不使用这些系统类，不保证受影响。
5. **设备验证边界**：本次修复可以在云端验证 arm64/arm64e 编译和包结构，但没有设备安装、注入日志或视觉回归，因此不能把云构建当成功能验收。

---

## 七、目录

```
Makefile                    构建（arm64 + arm64e，minos 15.0）
Tweak.xm                    键帽运行时 Hook 与圆角处理
KBRCKeyGeometry.h           键帽圆角纯几何策略（供源码与测试共用）
tests/key_geometry_test.c   几何边界单元测试
tests/check_keycap_contract.py 键帽目标与禁止误钩的静态保护
kbrc.plist                  MobileSubstrate 过滤器
control                     Debian 包描述
.github/workflows/build.yml 云端 macOS roothide 构建与测试
```

---

## 八、版本

| 版本 | 说明 |
|---|---|
| 1.0.0 | 初始实现曾将键盘背板作为圆角对象，未达到逐个键帽圆角的目标 |
| 1.0.1 | 改为针对 UIKBKeyView 键帽；按短边比例计算圆角，增加几何与目标类回归测试 |
| 1.0.2 | 注入过滤改为 `Bundles = com.apple.UIKit`，增加 Bundle filter 静态断言和进程诊断日志 |
