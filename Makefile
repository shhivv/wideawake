APP_NAME = WideAwake
APP_BUNDLE = $(APP_NAME).app

.PHONY: build app clean install run

build:
	swift build -c release

run:
	swift run

app: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	cp .build/release/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/
	codesign --force --sign - $(APP_BUNDLE)
	@echo "Built $(APP_BUNDLE)"

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)

install: app
	cp -r $(APP_BUNDLE) /Applications/
	@echo "Installed to /Applications/$(APP_BUNDLE)"

zip: app
	zip -r $(APP_NAME).zip $(APP_BUNDLE)
	shasum -a 256 $(APP_NAME).zip
