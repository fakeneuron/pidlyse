.PHONY: test build-release install dmg

# Run the Pidlyse test suite.
# CODE_SIGNING_ALLOWED=NO is required for CLI test runs (code-signing limitation
# in this environment); see .flowtron/tasknote/README.md "Project quick commands".
test:
	xcodebuild test -scheme Pidlyse -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO

# Ad-hoc signed Release build. Output: build/Release/Pidlyse.app
build-release:
	xcodebuild build -scheme Pidlyse -configuration Release \
		CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual SYMROOT=$(CURDIR)/build

install:
	ditto build/Release/Pidlyse.app /Applications/Pidlyse.app

# Package the Release build into a drag-install DMG with an /Applications symlink.
# Also emits build/Pidlyse.dmg.sha256 so a public download can publish a checksum
# users verify with `shasum -a 256 -c Pidlyse.dmg.sha256`.
dmg:
	mkdir -p build/dmg-staging
	cp -R build/Release/Pidlyse.app build/dmg-staging/
	ln -sf /Applications build/dmg-staging/Applications
	hdiutil create -volname Pidlyse -srcfolder build/dmg-staging -ov -format UDZO build/Pidlyse.dmg
	rm -rf build/dmg-staging
	cd build && shasum -a 256 Pidlyse.dmg | tee Pidlyse.dmg.sha256
