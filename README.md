# BirthTracker

BirthTracker is a SwiftUI iOS app for tracking birthdays of people you care about. It uses SwiftData with private CloudKit sync, plus WidgetKit snapshots for upcoming birthdays.

## Project Structure

Reusable code is organized with Swift Package Manager modules:

- `Sources/App`: app scene composition and dependency wiring.
- `Sources/Features`: SwiftUI screens and user flows.
- `Sources/Models`: SwiftData models and shared domain types.
- `Sources/Persistence`: SwiftData container setup, App Group access, and widget persistence constants.
- `Sources/DesignSystem`: reusable UI-adjacent settings and selection helpers.
- `Sources/TestingSupport`: fixtures and in-memory persistence helpers for tests and debug data.

The `BirthTrackerApp` and `BirthTrackerWidget` folders contain only target-specific entry points and plist files.

## Development

```bash
xcodegen generate
open BirthTracker.xcodeproj
```

Install local tooling before committing Swift changes:

```bash
brew install swift-format swiftlint
git config core.hooksPath .githooks
```

Format and lint checks can also be run manually:

```bash
make check
make fix
```

Create a local Xcode configuration before generating the project:

```bash
cp Config/Project.xcconfig.example Config/Project.xcconfig
```

Replace the placeholder bundle identifiers, CloudKit container, App Group, and team id in `Config/Project.xcconfig`. This file is ignored by git so local signing and app identifiers are not committed.

For Copilot worktree sessions, add `./scripts/copilot-session-create.sh` as a `session.create` lifecycle script. It copies the ignored local `Config/Project.xcconfig` from the main checkout into new worktrees when missing, falls back to `Config/Project.xcconfig.example`, runs `xcodegen generate`, runs `xcode-build-server config -workspace BirthTracker.xcodeproj/project.xcworkspace -scheme BirthTracker --build_root AIOutput/DerivedData`, builds the generated `buildServer.json` workspace and scheme for testing on the configured iOS Simulator using the same build root, and parses the Xcode result bundle into the xcode-build-server compile cache. The generated `buildServer.json` and compile cache let VS Code SourceKit-LSP resolve Swift build settings so clicking symbols, properties, and types can jump to their definitions.

Debug builds default to local SwiftData storage so unsigned simulator tests run reliably. Set `BIRTHTRACKER_STORAGE_MODE=memory`, `local`, or `cloud` to exercise the alternate storage modes.

Release builds use the private CloudKit database configured by `CLOUDKIT_CONTAINER_ID`.

## Release

GitHub Actions includes CI for project generation, build, tests, and fastlane validation. App Store Connect publishing uses `fastlane` with API key secrets.
