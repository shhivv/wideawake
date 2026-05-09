APP_NAME = WideAwake
APP_BUNDLE = $(APP_NAME).app

.PHONY: build app clean install run

build:
	swift build -c release

run:
	swift run

app: build icon
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp .build/release/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/
	cp Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/
	codesign --force --sign - $(APP_BUNDLE)
	@echo "Built $(APP_BUNDLE)"

icon: Resources/AppIcon.icns

Resources/AppIcon.icns: Resources/AppIcon.png
	rm -rf Resources/AppIcon.iconset
	mkdir -p Resources/AppIcon.iconset
	sips -z 1024 1024 $< --out Resources/AppIcon.iconset/icon_512x512@2x.png > /dev/null
	sips -z 512 512   $< --out Resources/AppIcon.iconset/icon_512x512.png > /dev/null
	sips -z 512 512   $< --out Resources/AppIcon.iconset/icon_256x256@2x.png > /dev/null
	sips -z 256 256   $< --out Resources/AppIcon.iconset/icon_256x256.png > /dev/null
	sips -z 256 256   $< --out Resources/AppIcon.iconset/icon_128x128@2x.png > /dev/null
	sips -z 128 128   $< --out Resources/AppIcon.iconset/icon_128x128.png > /dev/null
	sips -z 64 64     $< --out Resources/AppIcon.iconset/icon_32x32@2x.png > /dev/null
	sips -z 32 32     $< --out Resources/AppIcon.iconset/icon_32x32.png > /dev/null
	sips -z 32 32     $< --out Resources/AppIcon.iconset/icon_16x16@2x.png > /dev/null
	sips -z 16 16     $< --out Resources/AppIcon.iconset/icon_16x16.png > /dev/null
	iconutil -c icns Resources/AppIcon.iconset -o $@
	rm -rf Resources/AppIcon.iconset

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)

install: app
	cp -r $(APP_BUNDLE) /Applications/
	@echo "Installed to /Applications/$(APP_BUNDLE)"

zip: app
	zip -r $(APP_NAME).zip $(APP_BUNDLE)
	shasum -a 256 $(APP_NAME).zip
