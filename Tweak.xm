// ============================================================================
//  xxhook / Tweak.xm
//  「系统键盘圆角」—— 由 com.wkk.kbhook_1.0-1_iphoneos-arm64e.deb 逆向还原
//
//  还原依据：Keyboardhook.dylib 的 __text 只有 68 字节（17 条指令），
//  完整行为 = 1 个 constructor + 1 个替换函数，无 Logos 类、无偏好、无其他 hook。
//  逐指令对照见 ../kbhook_逆向分析报告.md
// ============================================================================

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// 目标键盘按键圆角（pt）。原版硬编码 10.0（机器码 fmov d0,#10.0 @0x7f38）。
// 改这一个数字即可调圆角大小，重新编译后行为等价于原来那条 fmov。
#define KB_CORNER_RADIUS 10.0

// 私有类：UIKit/UIKeyboard 的按键渲染几何信息。
// 原版仅引用类名字符串 "UIKBRenderGeometry" 与选择器 "setRoundRectRadius:"，
// 未引用任何其他成员，故此处只声明用到的属性。
@interface UIKBRenderGeometry : NSObject
@property (nonatomic) CGFloat roundRectRadius;
@end

// 原实现指针。Substrate 的 MSHookMessageEx 第 4 参数写入这里
// （对应二进制 __DATA.__bss @0xc020）。
static void (*orig_setRoundRectRadius)(id, SEL, CGFloat);

// 替换函数（对应二进制 0x7f30）。
// 原版逻辑：完全忽略系统传入的 radius，强制改成 10.0 再交给原实现。
static void kb_setRoundRectRadius(id self, SEL _cmd, CGFloat radius) {
    orig_setRoundRectRadius(self, _cmd, KB_CORNER_RADIUS);
}

// 对应二进制 0x7efc（__DATA_CONST.__mod_init_func 指向它）。
%ctor {
    Class cls = objc_getClass("UIKBRenderGeometry");

    // [加固] 原版无此判空，cls 为 nil 时 MSHookMessageEx 可能崩溃。
    // 行为上与原文一致（正常系统上 cls 恒非 nil），仅避免未来 iOS 改类名时炸掉。
    if (!cls) {
        NSLog(@"[xxhook] UIKBRenderGeometry not found, skip hook.");
        return;
    }

    MSHookMessageEx(cls,
                    @selector(setRoundRectRadius:),
                    (IMP)kb_setRoundRectRadius,
                    (IMP *)&orig_setRoundRectRadius);
}
