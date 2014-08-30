GO_EASY_ON_ME = 1
SDKVERSION = 7.0
ARCHS = armv7 arm64

include theos/makefiles/common.mk
TWEAK_NAME = Contrast70
Contrast70_FILES = Tweak.xm
Contrast70_FRAMEWORKS = CoreGraphics UIKit
Contrast70_LIBRARIES = Accessibility

include $(THEOS_MAKE_PATH)/tweak.mk
