TARGET := iphone:clang:latest:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TOOL_NAME = fridactrlhelper

fridactrlhelper_FILES = main.m
fridactrlhelper_CFLAGS = -fobjc-arc
fridactrlhelper_CODESIGN_FLAGS = -Sentitlements.plist
fridactrlhelper_INSTALL_PATH = /usr/bin

include $(THEOS_MAKE_PATH)/tool.mk
