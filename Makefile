# ClipCourt Makefile
#
# Tests ALWAYS run before building. This is enforced by making `build`
# depend on `test`. There is no way to build without passing tests first.
#
# Usage:
#   make          — test + build (default)
#   make build    — test + build (same thing — tests are mandatory)
#   make test     — run tests only
#   make clean    — clean derived data
#   make regen    — regenerate Xcode project from project.yml
#
# Why not a scheme pre-action?
#   XcodeGen scheme pre-actions that call `xcodebuild test -scheme X`
#   cause infinite recursion (the test triggers the build, which triggers
#   the pre-action, which triggers the test…). The Makefile is the
#   correct enforcement layer for "test before build" workflows.

SCHEME      := ClipCourt
PROJECT     := ClipCourt.xcodeproj
DEST        := platform=iOS Simulator,name=iPhone 17 Pro
TEST_TARGET := ClipCourtTests

.PHONY: all test build clean regen

# Default: test then build
all: build

# Build ALWAYS runs tests first — no exceptions
build: test
	@echo ""
	@echo "▶ Building ClipCourt…"
	@xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DEST)' \
		-quiet
	@echo "✅ Build succeeded"

# Run the test suite
test:
	@echo "▶ Running ClipCourt tests…"
	@xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DEST)' \
		-only-testing:$(TEST_TARGET) \
		-quiet
	@echo "✅ Tests passed"

# Regenerate Xcode project from project.yml
regen:
	@echo "▶ Regenerating Xcode project…"
	@cd "$(CURDIR)" && xcodegen generate
	@echo "✅ Project regenerated"

clean:
	@xcodebuild clean \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DEST)' \
		-quiet
	@echo "✅ Clean complete"
