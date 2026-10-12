.PHONY: test test-app coverage build-release install dmg build-cli install-cli

# Run the Pidlyse test suite: the app scheme, then the PidlyseCore package tests.
# CODE_SIGNING_ALLOWED=NO is required for CLI test runs (code-signing limitation
# in this environment); see .flaitron/tasknote/README.md "Project quick commands".
# `test-app` is the xcodebuild half alone so CI can name the package command
# itself without running that suite twice.
test: test-app
	swift test --package-path Packages/PidlyseCore

test-app:
	xcodebuild test -scheme Pidlyse -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO

# Run both test suites with code coverage and print one per-file report.
# The app scheme (PidlyseTests) and the SwiftPM scheme PidlyseCore-Package are
# separate xcodebuild invocations so `make test` and CI still execute the
# package suite once, via `swift test`. PidlyseCore-Package is invoked from
# the package directory: the app project's PidlyseCore scheme is the library
# product and has no test action. The two xcresults merge into
# build/coverage.xcresult (open in Xcode for the line-by-line view).
coverage:
	rm -rf build/coverage.xcresult build/coverage-app.xcresult build/coverage-core.xcresult
	xcodebuild test -scheme Pidlyse -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO \
		-enableCodeCoverage YES -resultBundlePath build/coverage-app.xcresult
	cd Packages/PidlyseCore && xcodebuild test -scheme PidlyseCore-Package -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO \
		-enableCodeCoverage YES -resultBundlePath $(CURDIR)/build/coverage-core.xcresult
	xcrun xcresulttool merge --output-path build/coverage.xcresult \
		build/coverage-app.xcresult build/coverage-core.xcresult
	rm -rf build/coverage-app.xcresult build/coverage-core.xcresult
	xcrun xccov view --report build/coverage.xcresult

# Ad-hoc signed Release build. Output: build/Release/Pidlyse.app
build-release:
	xcodebuild build -scheme Pidlyse -configuration Release \
		CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual SYMROOT=$(CURDIR)/build

install:
	ditto build/Release/Pidlyse.app /Applications/Pidlyse.app

# Build the pidlyse terminal companion (PID-EPIC-57).
# Output: Packages/PidlyseCore/.build/release/pidlyse
build-cli:
	swift build -c release --package-path Packages/PidlyseCore --product pidlyse

# Install the CLI to /usr/local/bin (may require sudo if root-owned).
install-cli: build-cli
	install -m 755 Packages/PidlyseCore/.build/release/pidlyse /usr/local/bin/pidlyse

# Package the Release build into a drag-install DMG with an /Applications symlink.
# Also emits build/Pidlyse.dmg.sha256 so a public download can publish a checksum
# users verify with `shasum -a 256 -c Pidlyse.dmg.sha256`.
dmg:
	mkdir -p build/dmg-staging build/dmg-mount
	cp -R build/Release/Pidlyse.app build/dmg-staging/
	ln -sf /Applications build/dmg-staging/Applications
	cp build/Release/Pidlyse.app/Contents/Resources/AppIcon.icns build/dmg-staging/.VolumeIcon.icns
	hdiutil create -volname Pidlyse -srcfolder build/dmg-staging -ov -format UDRW build/Pidlyse-rw.dmg
	hdiutil attach build/Pidlyse-rw.dmg -mountpoint build/dmg-mount -nobrowse -quiet
	SetFile -a C build/dmg-mount
	hdiutil detach build/dmg-mount -quiet
	hdiutil convert build/Pidlyse-rw.dmg -format UDZO -o build/Pidlyse.dmg -ov
	rm -f build/Pidlyse-rw.dmg
	rm -rf build/dmg-staging build/dmg-mount
	cd build && shasum -a 256 Pidlyse.dmg | tee Pidlyse.dmg.sha256
