.PHONY: test

# Run the Pidly test suite.
# CODE_SIGNING_ALLOWED=NO is required for CLI test runs (code-signing limitation
# in this environment); see .flowtron/tasknote/README.md "Project quick commands".
test:
	xcodebuild test -scheme Pidly -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
