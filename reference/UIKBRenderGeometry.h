// ============================================================================
//  参考资料，不参与编译（不要 #import 进 Tweak.xm）
//
//  UIKBRenderGeometry 是 UIKit 私有类，位于 UIKitCore。
//  下面只保留逆向时**有直接证据**的部分：
//    - 类名 "UIKBRenderGeometry"（__TEXT.__cstring @0x7f88）
//    - 选择器 "setRoundRectRadius:"（__TEXT.__objc_methname @0x7f9b）
//  其余成员未经证实，按需自行 dump：
//    class-dump-z / ipsw 里的 UIKitCore.tbd 符号 / iOS Runtime Headers
// ============================================================================

#import <Foundation/Foundation.h>

@interface UIKBRenderGeometry : NSObject
@property (nonatomic) CGFloat roundRectRadius;   // 对应 setter: setRoundRectRadius:
@end

// 调试期探针建议（不要留在发布版里）：
//   在 %ctor 里对 cls 做 class_copyMethodList()，
//   筛出名字含 RoundRect / Radius / Corner 的 selector，
//   可快速判断新 iOS 是否把圆角挪到了别的属性上。
