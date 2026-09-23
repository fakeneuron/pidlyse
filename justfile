# Project command interface — pidlyse.
#
# Uniform fleet verbs (`just test`, `just build`, …) so muscle memory transfers
# across repos; bodies are adapted to pidlyse's stack: a native macOS menu bar
# app built with Xcode / Swift Package Manager. The real commands live in the
# Makefile (`make test`/`build-release`/`install`/`dmg`) and xcodebuild; these
# recipes just give them uniform `just` names.
# Convention: natabula `docs/STACK-TENDENCIES.md` §"Command interface".
# Prerequisite: `just` (brew install just). Build/test require Xcode 15+, macOS 14+.
#
# Note: there is no CLI dev server — run the app interactively from Xcode (⌘R).
# There is no separate linter; the Swift compiler surfaces all type errors, so
# `lint` is a type-check via `xcodebuild build`.

# list available recipes
default:
    @just --list

# resolve Swift Package Manager dependencies
setup:
    xcodebuild -resolvePackageDependencies -scheme Pidlyse

# type-check (no separate linter; the Swift compiler surfaces all errors)
lint:
    xcodebuild build -scheme Pidlyse

# type-check — fleet `typecheck` verb; same xcodebuild build as `lint`
typecheck: lint

# run the test suite (CODE_SIGNING_ALLOWED=NO required for CLI runs)
test:
    make test

# build an ad-hoc signed Release .app → build/Release/Pidlyse.app
build:
    make build-release

# copy the Release build to /Applications
install:
    make install

# package the Release build into a drag-install DMG → build/Pidlyse.dmg
dmg:
    make dmg
