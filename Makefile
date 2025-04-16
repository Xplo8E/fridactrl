TARGET ?= iphone:clang:16.5:14
ARCHS ?= arm64
INSTALL_TARGET_PROCESSES = FridaCtrl

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = FridaCtrl

FridaCtrl_FILES = main.m XXAppDelegate.m XXRootViewController.m
FridaCtrl_ASSET_DIRS = Resources/Assets.xcassets
FridaCtrl_FRAMEWORKS = UIKit CoreGraphics Foundation
FridaCtrl_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/application.mk
SUBPROJECTS += fridactrlhelper
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "uicache -a && killall -9 SpringBoard"