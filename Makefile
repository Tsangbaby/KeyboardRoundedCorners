# Keyboard Rounded Corners (com.tsangbaby.kbrc)
# 目标系统：iOS 15 及以上
#
# 包形态三选一，只改下面这一行：
#   roothide  → roothide bootstrap（安装到 .jbroot，Architecture: iphoneos-arm64e）
#   rootless  → Dopamine / palera1n rootless（安装到 /var/jb）
#   留空      → 传统 rootful（安装到 /Library/MobileSubstrate）
export THEOS_PACKAGE_SCHEME = roothide

TARGET = iphone:clang:latest:15.0
ARCHS  = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = kbrc
kbrc_FILES      = Tweak.xm
kbrc_CFLAGS     = -fobjc-arc
kbrc_FRAMEWORKS = UIKit QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk

# 真机排查：make package FINALPACKAGE=1 DEBUG=1
ifeq ($(DEBUG),1)
kbrc_CFLAGS += -DKBRC_DEBUG=1
endif

# 键盘在各 App 进程内渲染，重装后必须重启目标 App；Respring 只刷新桌面
after-install::
	install.exec "killall -9 SpringBoard"
