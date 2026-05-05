# BirthTracker

BirthTracker is a SwiftUI iOS app for tracking birthdays of people you care about. It uses SwiftData with private CloudKit sync, plus WidgetKit snapshots for upcoming birthdays.

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

Debug builds default to local SwiftData storage so unsigned simulator tests run reliably. Set `BIRTHTRACKER_STORAGE_MODE=memory`, `local`, or `cloud` to exercise the alternate storage modes.

Release builds use the private CloudKit database configured by `CLOUDKIT_CONTAINER_ID`.

## Release

GitHub Actions includes CI for project generation, build, tests, and fastlane validation. App Store Connect publishing uses `fastlane` with API key secrets.
