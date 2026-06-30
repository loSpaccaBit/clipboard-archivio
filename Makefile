.PHONY: generate build install package clean i18n validate perf open help

APP_NAME := Appunti Archivio
SCHEME := ClipboardArchivio
CONFIG := Release
BUILD_DIR := build
PRODUCT := $(BUILD_DIR)/Build/Products/$(CONFIG)/$(APP_NAME).app
INSTALL_DIR := $(HOME)/Applications

help:
	@echo "Appunti Archivio — development commands"
	@echo ""
	@echo "  make generate   Regenerate Xcode project (xcodegen)"
	@echo "  make build      Build Release"
	@echo "  make install    Build and copy to ~/Applications"
	@echo "  make package    Build and create dist/*.dmg for release"
	@echo "  make open       Launch installed app"
	@echo "  make i18n       Rebuild localization catalog"
	@echo "  make validate   Validate i18n coverage"
	@echo "  make clean      Remove build artifacts"
	@echo "  make perf       Run performance smoke test"

generate:
	xcodegen generate

build: generate
	xcodebuild -scheme $(SCHEME) -configuration $(CONFIG) -derivedDataPath $(BUILD_DIR) build

install: build
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(PRODUCT)" "$(INSTALL_DIR)/"
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"

package: build
	chmod +x Scripts/package-dmg.sh
	Scripts/package-dmg.sh

open:
	open "$(INSTALL_DIR)/$(APP_NAME).app"

i18n:
	python3 Scripts/i18n/build-catalog.py

validate:
	python3 Scripts/i18n/validate-i18n.py

clean:
	rm -rf $(BUILD_DIR)

perf:
	@bash Scripts/performance-test.sh