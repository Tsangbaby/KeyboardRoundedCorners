//
//  Keyboard Rounded Corners  (com.tsangbaby.kbrc)
//  iOS 15+
//
//  作用：把系统键盘面板（模糊背板 / 背景板）裁成圆角卡片，四个角都圆。
//
//  为什么用「运行时枚举 + 几何过滤」而不是直接 %hook UIKBBackdropView：
//    键盘背板类在 iOS 15 → 18 之间被改过名、部分实现还从 UIKitCore 挪进了 TextInputUI，
//    写死类名只会在某些系统上静默失效（连日志都没有）。这里改成：
//      ① 枚举所有类，取「名字含 UIKB / UIKeyboard / TUIKeyboard」且「含 Backdrop / BackgroundView」的；
//      ② 对它们各自的 layoutSubviews 做 swizzle（只动类自己实现了 layoutSubviews 的，避免污染父类）；
//      ③ 布局完成后再用几何条件确认「这确实是一整块键盘面板」才施加圆角。
//    改名、换框架都不影响，最坏情况是枚举不到 → 日志里会明确告诉你。
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <string.h>
#import <stdlib.h>
#import <substrate.h>

// ============================================================================
//  可调参数
// ============================================================================

/// 圆角半径（pt）。想要更圆就调大，系统级观感一般 10~14。
static const CGFloat kKBRCCornerRadius = 12.0;

/// 只有「宽度 ≥ 屏宽 × 该比例」且「高度 ≥ kKBRCMinHeight」的视图才被当作键盘面板。
/// 这条是安全阀：避免误伤键盘内部的小背板、候选栏、单个按键。
static const CGFloat kKBRCMinScreenWidthRatio = 0.80;
static const CGFloat kKBRCMinHeight = 120.0;

/// 调试日志：make package DEBUG=1 打开。会打印命中的类名与所有候选类，用于真机定位。
#ifndef KBRC_DEBUG
#define KBRC_DEBUG 0
#endif

#if KBRC_DEBUG
#define KBRCLog(fmt, ...) NSLog(@"[kbrc] " fmt, ##__VA_ARGS__)
#else
#define KBRCLog(fmt, ...) do {} while (0)
#endif

// ============================================================================
//  swizzle 表：同一个替换函数要服务多个类，所以按 (类, 选择器) 查原始 IMP
// ============================================================================

typedef struct {
    __unsafe_unretained Class cls;
    SEL sel;
    IMP orig;
} KBRCHookEntry;

static KBRCHookEntry gEntries[32];
static int gEntryCount = 0;

static IMP KBRCOriginalFor(Class cls, SEL sel) {
    for (Class c = cls; c != Nil; c = class_getSuperclass(c)) {
        for (int i = 0; i < gEntryCount; i++) {
            if (gEntries[i].cls == c && sel_isEqual(gEntries[i].sel, sel)) {
                return gEntries[i].orig;
            }
        }
    }
    return NULL;
}

static BOOL KBRCIsHooked(Class cls, SEL sel) {
    for (int i = 0; i < gEntryCount; i++) {
        if (gEntries[i].cls == cls && sel_isEqual(gEntries[i].sel, sel)) return YES;
    }
    return NO;
}

// ============================================================================
//  施加圆角
// ============================================================================

/// 返回 YES 表示「已经处理过这个视图」（无论这次是否新设置了圆角）
static BOOL KBRCApplyCornerRadius(UIView *view) {
    if (view == nil) return NO;

    const CGRect bounds = view.bounds;
    const CGSize screen = UIScreen.mainScreen.bounds.size;
    if (screen.width <= 0.0 || bounds.size.width <= 0.0) return NO;

    if (bounds.size.width < screen.width * kKBRCMinScreenWidthRatio) return NO;
    if (bounds.size.height < kKBRCMinHeight) return NO;

    CALayer *layer = view.layer;
    if (layer == nil) return NO;
    if (layer.cornerRadius == kKBRCCornerRadius && layer.masksToBounds) return YES;   // 已处理过

    layer.cornerRadius = kKBRCCornerRadius;
    layer.cornerCurve = kCACornerCurveContinuous;   // iOS 13+，圆角过渡更接近系统
    layer.masksToBounds = YES;

    KBRCLog(@"rounded %s  %.0fx%.0f", class_getName(object_getClass(view)),
            bounds.size.width, bounds.size.height);
    return YES;
}

/// 所有被 hook 的方法都走这里：先跑原实现，再尝试施加圆角
static void KBRCViewDidLayout(id self, SEL _cmd) {
    IMP orig = KBRCOriginalFor(object_getClass(self), _cmd);
    if (orig) {
        ((void (*)(id, SEL))orig)(self, _cmd);
    }

    if (KBRCApplyCornerRadius((UIView *)self)) return;

    // didMoveToWindow 时机可能还没布局（bounds 仍是 0），下一帧再补一次
    if (sel_isEqual(_cmd, @selector(didMoveToWindow))) {
        __weak UIView *weakView = (UIView *)self;
        dispatch_async(dispatch_get_main_queue(), ^{
            UIView *view = weakView;
            if (view != nil) KBRCApplyCornerRadius(view);
        });
    }
}

// ============================================================================
//  安装
// ============================================================================

static void KBRCInstallOnClass(Class cls) {
    if (cls == Nil || gEntryCount >= 32) return;

    // 优先 layoutSubviews；类自己没实现时才退回 didMoveToWindow
    const SEL preferred[] = { @selector(layoutSubviews), @selector(didMoveToWindow) };

    for (int s = 0; s < (int)(sizeof(preferred) / sizeof(preferred[0])); s++) {
        SEL sel = preferred[s];
        if (KBRCIsHooked(cls, sel)) return;

        unsigned int count = 0;
        Method target = NULL;
        Method *list = class_copyMethodList(cls, &count);
        for (unsigned int i = 0; i < count; i++) {
            if (sel_isEqual(method_getName(list[i]), sel)) {
                target = list[i];   // 只处理「类自己实现」的方法，不碰继承来的
                break;
            }
        }
        free(list);

        if (target == NULL) continue;

        gEntries[gEntryCount].cls = cls;
        gEntries[gEntryCount].sel = sel;
        gEntries[gEntryCount].orig = method_getImplementation(target);
        gEntryCount++;

        method_setImplementation(target, (IMP)KBRCViewDidLayout);
        KBRCLog(@"hooked -[%s %s]", class_getName(cls), sel_getName(sel));
        return;   // 同一个类只挂一个入口即可
    }
}

static BOOL KBRCNameLooksLikeKeyboardBackground(const char *name) {
    if (name == NULL || name[0] == '\0') return NO;

    const BOOL keyboardish = (strstr(name, "UIKB") != NULL) ||
                             (strstr(name, "UIKeyboard") != NULL) ||
                             (strstr(name, "TUIKeyboard") != NULL);
    if (!keyboardish) return NO;

    return (strstr(name, "Backdrop") != NULL) || (strstr(name, "BackgroundView") != NULL);
}

static int KBRCInstallAll(void) {
    int total = objc_getClassList(NULL, 0);
    if (total <= 0) return 0;

    Class *classes = (Class *)malloc(sizeof(Class) * (size_t)total);
    if (classes == NULL) return 0;
    total = objc_getClassList(classes, total);

    int matched = 0;
    for (int i = 0; i < total; i++) {
        const char *name = class_getName(classes[i]);
#if KBRC_DEBUG
        // 把所有「跟键盘沾边」的类都打出来：即使没命中，也能在日志里看到真名，
        // 直接照着改 KBRCNameLooksLikeKeyboardBackground 即可
        if (strstr(name, "Keyboard") != NULL || strstr(name, "UIKB") != NULL) {
            KBRCLog(@"kb-class: %s", name);
        }
#endif
        if (KBRCNameLooksLikeKeyboardBackground(name)) {
            matched++;
            KBRCInstallOnClass(classes[i]);
        }
    }
    free(classes);

    return matched;
}

// ============================================================================
//  入口
// ============================================================================

/// 极少见情况：本插件比 UIKitCore 更早加载，此时类还没注册完。
/// 半秒后补一次即可；仍然失败只影响功能，不影响进程。
static void KBRCScheduleRetry(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        // 注意：KBRCInstallAll() 不能写在 KBRCLog 的参数里——release 构建会把宏展开成空语句
        int matched = KBRCInstallAll();
        (void)matched;
        KBRCLog(@"retry: matched %d classes", matched);
    });
}

%ctor {
    if (KBRCInstallAll() == 0) {
        KBRCScheduleRetry();
    }
}
