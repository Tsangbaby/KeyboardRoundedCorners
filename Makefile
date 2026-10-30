# ============================================================================
#  xxhook —— 由 com.wkk.kbhook_1.0-1_iphoneos-arm64e.deb 逆向还原
#
#  Historical claims from the supplied archive; original binary not provided.
#  Current build uses the selected Apple SDK and retains iOS 15.0 deployment.
#  原附件记载的对应关系（未独立验证）：
#    LC_ID_DYLIB      = @loader_path/.jbroot/Library/MobileSubstrate/DynamicLibraries/xxhook.dylib
#                       → 原工程名是 xxhook（发布时把文件名改成了 Keyboardhook）
#                       → .jbroot 前缀说明构建时 THEOS_PACKAGE_SCHEME = roothide
#    LC_BUILD_VERSION = platform iOS, minos 15.0, sdk 16.4
#    fat 切片         = arm64 + arm64e      → ARCHS = arm64 arm64e
#    链接库           = libobjc / Foundation / CoreFoundation / UIKit / libc++ / libSystem / substrate
#                       → Tweak.xm 按 ObjC++ 编译（libc++ 是 Theos 编 .xm 的默认产物）
# ============================================================================

TARGET = iphone:clang:latest:15.0
# Compile against the selected Apple SDK while retaining the iOS 15.0 floor.

ARCHS = arm64 arm64e

# 原包 install_name 带 .jbroot → roothide bootstrap。
# 若你要出 rootless（Dopamine / palera1n）包，改成 rootless；
# 出 rootful（unc0ver / checkra1n）包则整行删掉。
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = xxhook
xxhook_FILES = Tweak.xm
xxhook_FRAMEWORKS = UIKit Foundation
xxhook_LIBRARIES = substrate
xxhook_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
