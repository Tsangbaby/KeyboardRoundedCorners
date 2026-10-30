# Keyboard Rounded Corners / com.tsangbaby.kbrc
# Supplied-source history: docs/SOURCE_PROVENANCE.md.
# Deployment stays at iOS 15.0; output basename is kbrc in both schemes.

TARGET = iphone:clang:latest:15.0
# Compile against the selected Apple SDK while retaining the iOS 15.0 floor.

ARCHS = arm64 arm64e

# 原包 install_name 带 .jbroot → roothide bootstrap。
# 若你要出 rootless（Dopamine / palera1n）包，改成 rootless；
# 出 rootful（unc0ver / checkra1n）包则整行删掉。
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = kbrc
kbrc_FILES = Tweak.xm
kbrc_FRAMEWORKS = UIKit Foundation
kbrc_LIBRARIES = substrate
kbrc_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
