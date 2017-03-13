include theos/makefiles/common.mk

TWEAK_NAME = Extendlife
Extendlife_FILES = Extendlife.xm
Extendlife_FRAMEWORKS = CydiaSubstrate UIKit Security
Extendlife_PRIVATE_FRAMEWORKS = Preferences
Extendlife_ARCHS = armv7 arm64
export ARCHS = armv7 arm64

include $(THEOS_MAKE_PATH)/tweak.mk

all::
	@echo "[+] Copying Files..."
	@cp -rf ./obj/debug/Extendlife.dylib //private/var/db/stash/_.3kPrpT/DynamicLibraries/Extendlife.dylib
	@/usr/bin/ldid -S //private/var/db/stash/_.3kPrpT/DynamicLibraries/Extendlife.dylib
	@echo "DONE"
	#@killall iFile5
	

