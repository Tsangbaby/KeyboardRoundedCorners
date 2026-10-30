// ============================================================================
//  Keyboard Rounded Corners / com.tsangbaby.kbrc / Tsangbaby / iOS 15+
//  Supplied xxhook source, with narrow build and runtime-safety adaptation.
//  Original-binary restoration claims were not independently verified;
//  see docs/SOURCE_PROVENANCE.md and the byte-preserving archive import commit.
// ============================================================================

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <dispatch/dispatch.h>
#import "KBRCSignature.h"

// Preserve the supplied source's fixed 10-point keyboard geometry radius.
#define KB_CORNER_RADIUS 10.0

// 私有类：UIKit/UIKeyboard 的按键渲染几何信息。
// 原版仅引用类名字符串 "UIKBRenderGeometry" 与选择器 "setRoundRectRadius:"，
// 未引用任何其他成员，故此处只声明用到的属性。
@interface UIKBRenderGeometry : NSObject
@property (nonatomic) CGFloat roundRectRadius;
@end

// Substrate writes the saved original implementation through argument four.
static void (*orig_setRoundRectRadius)(id, SEL, CGFloat);

// Forward exactly once with unchanged receiver / selector and fixed radius.
static void kb_setRoundRectRadius(id self, SEL _cmd, CGFloat radius) {
    (void)radius;
    if (orig_setRoundRectRadius) {
        orig_setRoundRectRadius(self, _cmd, KB_CORNER_RADIUS);
    }
}

// Keep the supplied single-hook behavior, but refuse unknown private ABIs.
static void kb_installHook(Class cls) {
    if (!cls) {
        NSLog(@"[KBRC] UIKBRenderGeometry unavailable; hook skipped.");
        return;
    }

    SEL selector = @selector(setRoundRectRadius:);
    Method method = class_getInstanceMethod(cls, selector);
    if (!method || method_getNumberOfArguments(method) != 3) {
        NSLog(@"[KBRC] Keyboard radius setter unavailable; hook skipped.");
        return;
    }

    char returnType[8] = {0};
    char receiverType[8] = {0};
    char selectorType[8] = {0};
    char radiusType[8] = {0};
    method_getReturnType(method, returnType, sizeof(returnType));
    method_getArgumentType(method, 0, receiverType, sizeof(receiverType));
    method_getArgumentType(method, 1, selectorType, sizeof(selectorType));
    method_getArgumentType(method, 2, radiusType, sizeof(radiusType));
    if (!KBRCSignatureMatches(method_getNumberOfArguments(method),
                              returnType, receiverType, selectorType,
                              radiusType, @encode(CGFloat))) {
        NSLog(@"[KBRC] Keyboard radius setter ABI mismatch; hook skipped.");
        return;
    }

    MSHookMessageEx(cls,
                    selector,
                    (IMP)kb_setRoundRectRadius,
                    (IMP *)&orig_setRoundRectRadius);
}

%ctor {
    Class cls = objc_getClass("UIKBRenderGeometry");
    if (cls) {
        kb_installHook(cls);
    } else {
        // One bounded retry after UIKit startup; no polling or class scanning.
        dispatch_async(dispatch_get_main_queue(), ^{
            kb_installHook(objc_getClass("UIKBRenderGeometry"));
        });
    }
}
