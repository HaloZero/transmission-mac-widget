SCHEME := TransmissionWidgetHost
PROJECT := TransmissionWidgetHost.xcodeproj
CONFIGURATION := Release
BUILD_DIR := build
ARCHIVE_PATH := $(BUILD_DIR)/$(SCHEME).xcarchive
EXPORT_PATH := $(BUILD_DIR)/export
EXPORT_OPTIONS := $(BUILD_DIR)/ExportOptions.plist
APP_PATH := $(EXPORT_PATH)/$(SCHEME).app

# Pulled from project.yml so there's one place to set your team, not two.
# See the README's Warnings section — this must be your own team, not the
# one checked into this repo.
TEAM_ID := $(shell grep 'DEVELOPMENT_TEAM' project.yml | sed -E 's/[^"]*"([^"]+)".*/\1/')

.PHONY: generate archive export app install clean

generate:
	xcodegen generate

$(EXPORT_OPTIONS): project.yml
	@mkdir -p $(BUILD_DIR)
	@if [ -z "$(TEAM_ID)" ]; then \
		echo "error: could not read DEVELOPMENT_TEAM from project.yml"; \
		exit 1; \
	fi
	@rm -f $(EXPORT_OPTIONS)
	@plutil -create xml1 $(EXPORT_OPTIONS)
	@plutil -insert method -string mac-application $(EXPORT_OPTIONS)
	@plutil -insert teamID -string "$(TEAM_ID)" $(EXPORT_OPTIONS)
	@plutil -insert signingStyle -string automatic $(EXPORT_OPTIONS)

archive: generate
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-archivePath $(ARCHIVE_PATH) \
		-destination "generic/platform=macOS" \
		-allowProvisioningUpdates

export: archive $(EXPORT_OPTIONS)
	rm -rf $(EXPORT_PATH)
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist $(EXPORT_OPTIONS)

# Alias for "the thing you actually want": a signed, runnable .app.
app: export
	@echo "Built $(APP_PATH)"

install: app
	cp -R "$(APP_PATH)" /Applications/
	@echo "Installed to /Applications — right-click it and choose Open on"
	@echo "first launch (unsigned/un-notarized build, so Gatekeeper will warn once)."

clean:
	rm -rf $(BUILD_DIR)
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION)
