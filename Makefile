.PHONY: test build-release install

# Run the Pidly test suite.
# CODE_SIGNING_ALLOWED=NO is required for CLI test runs (code-signing limitation
# in this environment); see .flowtron/tasknote/README.md "Project quick commands".
test:
	xcodebuild test -scheme Pidly -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO

# Ad-hoc signed Release build. Output: build/Release/Pidly.app
build-release:
	xcodebuild build -scheme Pidly -configuration Release \
		CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual SYMROOT=$(CURDIR)/build

install:
	ditto build/Release/Pidly.app /Applications/Pidly.app
