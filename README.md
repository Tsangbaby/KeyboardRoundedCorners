# Keyboard Rounded Corners

给 iOS 系统键盘加上圆角，四个角都圆。iOS 15 及以上。

- 包名：`com.tsangbaby.kbrc`
- 作者 / 维护者：Tsangbaby
- 产物：`kbrc.dylib`（arm64 + arm64e）

---

## 一、它是怎么做的

```
注入    kbrc.plist → Classes = UIKeyboardImpl（凡是会弹键盘的进程都注入）
发现    运行时枚举所有类，取「名字含 UIKB / UIKeyboard / TUIKeyboard」
        且「含 Backdrop / BackgroundView」的类 —— 也就是键盘的背板/底板
挂载    对每个类「自己实现」的 layoutSubviews 做 swizzle（不碰继承来的，不污染父类）
施加    布局完成后做几何确认：宽度 ≥ 屏宽×0.8、高度 ≥ 120 → 施加圆角 + 裁剪
```

### 为什么不直接 `%hook UIKBBackdropView`

这是本次重写最关键的一个决定。键盘背板类在 iOS 15 → 18 之间**改过名**，部分实现还从 UIKitCore 挪进了 TextInputUI。写死类名会带来最糟糕的失败模式：**静默失效**——装上去毫无反应，也没有任何日志。

所以改成「类名模式 + 几何双重过滤」：

- 改名不要紧，只要还叫 `*Backdrop*` / `*BackgroundView*` 就能被枚举到；
- 几何过滤保证「只可能是整块键盘面板」才动手，键盘内部的小背板、候选栏、单个按键一律跳过；
- 真出问题时，`DEBUG=1` 的日志会直接列出**所有候选类**和**实际挂上的类**，不用猜。

---

## 二、构建

需要 [Theos](https://github.com/theos/theos)。没有 Mac 就用仓库里的 GitHub Actions。

```bash
export THEOS=~/theos
make package FINALPACKAGE=1
# 产物：packages/com.tsangbaby.kbrc_1.0.0_*.deb
```

包形态在 `Makefile` 第一行切换（默认 roothide）：

| 你的环境 | 设置 |
|---|---|
| roothide bootstrap | `THEOS_PACKAGE_SCHEME = roothide`（默认） |
| Dopamine / palera1n rootless | `THEOS_PACKAGE_SCHEME = rootless` |
| 传统 rootful | 这一行留空 |

---

## 三、安装与生效

```bash
dpkg -i com.tsangbaby.kbrc_1.0.0_*.deb
killall -9 SpringBoard
```

装完后**重启目标 App** 才会重新注入（键盘在 App 进程内渲染，Respring 只刷新桌面）。然后随便点一个输入框，键盘应该变成圆角卡片。

---

## 四、没生效怎么查（3 分钟）

```bash
make clean && make package FINALPACKAGE=1 DEBUG=1
# 装包后
log stream --predicate 'eventMessage CONTAINS "[kbrc]"' --style compact
```

日志会分三类：

| 日志 | 含义 | 下一步 |
|---|---|---|
| `kb-class: XXX` | 你这台设备上**所有**跟键盘沾边的类（DEBUG 全量打印） | 从里面挑出像「背板/底板」的那个 |
| `hooked -[XXX layoutSubviews]` | 实际挂上的类 | 一条都没有 → 注入没成功，或类名模式没覆盖到 |
| `rounded XXX 390x291` | 圆角已施加 | 有这条但视觉没变 → 见「已知不确定项」第 2 条 |

如果 `hooked` 一条都没有，就到 `kb-class` 里找真名，改 `Tweak.xm` 里的 `KBRCNameLooksLikeKeyboardBackground()`（比如把关键字换成 `Keyplane`、`Layout`、`Backdrop` 的组合），重新打包再看。

---

## 五、可调参数

| 常量 | 默认 | 作用 |
|---|---|---|
| `kKBRCCornerRadius` | `12.0` | 圆角半径（pt） |
| `kKBRCMinScreenWidthRatio` | `0.80` | 宽度 ≥ 屏宽×该值才算「整块键盘面板」 |
| `kKBRCMinHeight` | `120.0` | 高度下限，挡住候选栏等窄条 |

都在 `Tweak.xm` 顶部，改完重新打包即可。

---

## 六、已知不确定项（请当成待验证清单，不是免责声明）

1. **背板类名是按公开资料 + 经验给的模式**，没有在你的设备上实跑过。第一次装包请务必按第四节看一遍日志。
2. **如果日志显示 `rounded` 了但视觉仍是方角**，通常是「背板被圆了，但它外面还有一层方形的底色/分割层」。处理办法：把 `UIKBBackgroundView` 之外的容器类也纳入匹配（改 `KBRCNameLooksLikeKeyboardBackground` 的返回条件），或把 `kKBRCMinScreenWidthRatio` 调低一点让它也命中。
3. **底部两个角会露出 App 内容**（这是你选的「四角全圆」的必然结果）。只想要顶部圆角的话，把 `KBRCApplyCornerRadius` 里的
   `layer.cornerRadius = ...` 换成分象限的 `maskedCorners`（`kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner`）。
4. **第三方键盘不受影响**：它们自绘 UI，不走系统背板类，本来也不该被改。
5. **iPad 浮动/分屏键盘**：系统已经给了圆角，且宽度不足 0.8 屏宽，会被几何过滤跳过。
6. **横屏**：几何条件用的是 `UIScreen.mainScreen.bounds`，横屏时宽度同步变化，逻辑一致。

---

## 七、目录

```
Makefile                    构建（arm64 + arm64e，minos 15.0）
Tweak.xm                    全部实现（约 200 行，含注释）
kbrc.plist                  MobileSubstrate 过滤器
control                     Debian 包描述
.github/workflows/build.yml 云端 macOS 构建
```

---

## 八、版本

| 版本 | 说明 |
|---|---|
| 1.0.0 | 首版。键盘面板四角圆角，iOS 15+ |
