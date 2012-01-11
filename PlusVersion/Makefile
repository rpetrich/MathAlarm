TWEAK_NAME = MathAlarm
MathAlarm_FILES = Tweak.x
MathAlarm_FRAMEWORKS = UIKit
MathAlarm_CFLAGS = -DPRO_VERSION

include framework/makefiles/common.mk
include framework/makefiles/tweak.mk

ifeq ($(FINALPACKAGE),1)
THEOS_PACKAGE_FILENAME = cydiastore_$(THEOS_PACKAGE_NAME)_v$(THEOS_PACKAGE_BASE_VERSION)
else
THEOS_PACKAGE_FILENAME = cydiastore_$(THEOS_PACKAGE_NAME)_v$(_THEOS_PACKAGE_LAST_VERSION)
endif

