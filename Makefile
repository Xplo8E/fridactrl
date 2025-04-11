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

do::
	actool Resources/Assets.xcassets --compile ./Resources --platform iphoneos  --minimum-deployment-target 8.0 --app-icon AppIcon --launch-image LaunchImage --output-partial-info-plist tmp.plist
	/usr/libexec/PlistBuddy -x -c "Merge tmp.plist" ./Resources/Info.plist
	rm tmp.plist