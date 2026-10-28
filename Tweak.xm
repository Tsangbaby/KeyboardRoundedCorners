//
//  Keyboard Rounded Corners  (com.tsangbaby.kbrc)
//  iOS 15+
//
//  作用：把系统键盘里的每个键位（keycap）裁成连续圆角。
//
// 目标是 UIKBKeyView / UIKBContainerKeyView 这一层的键帽视图，而不是 UIKBBackdropView。
// 键盘背板决定整块键盘的外框；键位视图才是图片中每个字母键、功能键和
// 空格键的白色/灰色圆角背景。
//
// 运行时只选取明确的系统键帽类名（兼顾 UIKitCore 与 TextInputUI 命名），
// 再替换类自己实现的无参数生命周期入口；不会把 UIView 通用方法改掉，
// 也不会再误伤整块键盘背板。
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <string.h>
#import <stdlib.h>
#import <math.h>
#import <substrate.h>
#import "KBRCKeyGeometry.h"

// ============================================================================
//  调试日志：make package DEBUG=1 打开
// ============================================================================
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

static KBRCHookEntry gEntries[64];
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
//  施加键位圆角
// ============================================================================

/// 只对已经由类名过滤确认的键位视图调用，不再使用整块键盘的宽高门槛。
static BOOL KBRCApplyKeyCapRadius(UIView *view) {
    if (view == nil) return NO;

    const CGRect bounds = view.bounds;
    CGFloat radius = (CGFloat)KBRCKeyCapCornerRadiusForSize(
        CGRectGetWidth(bounds), CGRectGetHeight(bounds));
    if (radius <= 0.0) return NO;

    CALayer *layer = view.layer;
    if (layer == nil) return NO;

    if (fabs(layer.cornerRadius - radius) < 0.01 && layer.masksToBounds) {
        return YES;   // 已处理过
    }

    layer.cornerRadius = radius;
    layer.cornerCurve = kCACornerCurveContinuous;
    layer.masksToBounds = YES;

    KBRCLog(@"rounded keycap %s %.1fx%.1f radius=%.1f",
            class_getName(object_getClass(view)),
            CGRectGetWidth(bounds), CGRectGetHeight(bounds), radius);
    return YES;
}

/// 所有被 hook 的无参数布局方法都走这里：先跑原实现，再处理键位。
static void KBRCKeyViewDidLayout(id self, SEL _cmd) {
    IMP orig = KBRCOriginalFor(object_getClass(self), _cmd);
    if (orig) {
        ((void (*)(id, SEL))orig)(self, _cmd);
    }

    if (KBRCApplyKeyCapRadius((UIView *)self)) return;

    // prepareForDisplay may run before the final keycap dimensions are set.
    // Apply once more on the next main-queue turn in that case.
    if (sel_isEqual(_cmd, @selector(didMoveToWindow)) ||
        sel_isEqual(_cmd, @selector(prepareForDisplay))) {
        __weak UIView *weakView = (UIView *)self;
        dispatch_async(dispatch_get_main_queue(), ^{
            UIView *view = weakView;
            if (view != nil) KBRCApplyKeyCapRadius(view);
        });
    }
}

// ============================================================================
//  安装
// ============================================================================

static BOOL KBRCIsVoidNoArgumentMethod(Method method) {
    if (method == NULL || method_getNumberOfArguments(method) != 2) return NO;

    char returnType[8] = {0};
    method_getReturnType(method, returnType, sizeof(returnType));
    return strcmp(returnType, @encode(void)) == 0;
}

static void KBRCInstallOnClass(Class cls) {
    if (cls == Nil) return;

    // Avoid installing the same selector on ancestor and subclass: calling
    // super could otherwise re-enter the subclass wrapper. UIKBContainerKeyView
    // derives from UIKBKeyView, so each owner receives a distinct entry point.
    const char *className = class_getName(cls);
    SEL preferred[1];
    if (strcmp(className, "UIKBKeyView") == 0) {
        preferred[0] = @selector(layoutSubviews);
    } else if (strcmp(className, "UIKBContainerKeyView") == 0) {
        preferred[0] = @selector(prepareForDisplay);
    } else {
        return;
    }

    const int capacity = (int)(sizeof(gEntries) / sizeof(gEntries[0]));
    if (gEntryCount >= capacity || KBRCIsHooked(cls, preferred[0])) return;

    unsigned int count = 0;
    Method *list = class_copyMethodList(cls, &count);
    if (list == NULL) return;

    Method target = NULL;
    for (unsigned int i = 0; i < count; i++) {
        if (sel_isEqual(method_getName(list[i]), preferred[0]) &&
            KBRCIsVoidNoArgumentMethod(list[i])) {
            target = list[i];
            break;
        }
    }
    free(list);
    if (target == NULL) return;

    gEntries[gEntryCount].cls = cls;
    gEntries[gEntryCount].sel = preferred[0];
    gEntries[gEntryCount].orig = method_getImplementation(target);
    gEntryCount++;

    method_setImplementation(target, (IMP)KBRCKeyViewDidLayout);
    KBRCLog(@"hooked keycap -[%s %s]", className, sel_getName(preferred[0]));
}

static BOOL KBRCNameLooksLikeKeyboardKey(const char *name) {
    // UIKBKeyView draws classic keycaps. UIKBContainerKeyView is the
    // container superclass used by floating and newer TextInputUI key views.
    // Keep exact class matching to avoid backdrop, blur and helper views.
    return name != NULL &&
           (strcmp(name, "UIKBKeyView") == 0 ||
            strcmp(name, "UIKBContainerKeyView") == 0);
}

static int KBRCInstallAll(void) {
    int total = objc_getClassList(NULL, 0);
    if (total <= 0) return gEntryCount;

    Class *classes = (Class *)malloc(sizeof(Class) * (size_t)total);
    if (classes == NULL) return gEntryCount;
    total = objc_getClassList(classes, total);

    int matched = 0;
    for (int i = 0; i < total; i++) {
        const char *name = class_getName(classes[i]);
#if KBRC_DEBUG
        // DEBUG 下列出键盘相关类，便于确认目标系统实际使用的 KeyView 名称。
        if (strstr(name, "Keyboard") != NULL ||
            strstr(name, "UIKB") != NULL ||
            strstr(name, "TUI") != NULL) {
            KBRCLog(@"keyboard-class: %s", name);
        }
#endif
        if (KBRCNameLooksLikeKeyboardKey(name)) {
            matched++;
            KBRCInstallOnClass(classes[i]);
        }
    }
    free(classes);

    KBRCLog(@"keycap scan: matched=%d hooked=%d", matched, gEntryCount);
    return gEntryCount;
}

// ============================================================================
//  入口
// ============================================================================

/// 极少见情况：本插件比 UIKitCore/TextInputUI 更早加载，此时类还没注册完。
/// 半秒后补一次；仍然失败只影响功能，不影响进程。
static void KBRCScheduleRetry(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        int hooked = KBRCInstallAll();
        (void)hooked;
        KBRCLog(@"retry: hooked %d keycap classes", hooked);
    });
}

%ctor {
    if (KBRCInstallAll() == 0) {
        KBRCScheduleRetry();
    }
}
