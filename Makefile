.PHONY: generate icon build install package pkg clean i18n validate perf open help

APP_NAME := Clipboard Archive
SCHEME := ClipboardArchivio
CONFIG := Release
BUILD_DIR := build
PRODUCT := $(BUILD_DIR)/Build/Products/$(CONFIG)/$(APP_NAME).app
INSTALL_DIR := $(HOME)/Applications
ICON_FILE := ClipboardArchivio/Resources/AppIcon.icns

help:
	@echo "Clipboard Archive — development commands"
	@echo ""
	@echo "  make generate   Regenerate Xcode project (xcodegen)"
	@echo "  make icon       Generate AppIcon.icns from docs/assets/logo.svg"
	@echo "  make build      Build Release"
	@echo "  make install    Build and copy to ~/Applications"
	@echo "  make package    Build and create DMG (standard PKG install app)"
	@echo "  make pkg        Build optional .pkg installer (maintainers)"
	@echo "  make open       Launch installed app"
	@echo "  make i18n       Rebuild localization catalog"
	@echo "  make validate   Validate i18n coverage"
	@echo "  make clean      Remove build artifacts"
	@echo "  make perf       Run performance smoke test"

generate:
	xcodegen generate

icon: docs/assets/logo.svg Scripts/generate-app-icon.sh
	chmod +x Scripts/generate-app-icon.sh
	Scripts/generate-app-icon.sh

build: generate icon
	xcodebuild -scheme $(SCHEME) -configuration $(CONFIG) -derivedDataPath $(BUILD_DIR) build

install: build
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(PRODUCT)" "$(INSTALL_DIR)/"
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"

package: build
	chmod +x Scripts/package-dmg.sh
	Scripts/package-dmg.sh
	mkdir -p docs/download
	cp dist/Clipboard-Archive.dmg docs/download/Clipboard-Archive.dmg
	@echo "Copied DMG to docs/download/ for GitHub Pages direct download"

pkg: build
	chmod +x Scripts/package-installer.sh
	Scripts/package-installer.sh

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