# Generic iOS Project Template Requirements

This document defines the baseline requirements for creating a reusable native iOS project template. It is not tied to a specific app domain. Each new app created from this template should provide its own product name, bundle identifier, app features, data models, and CloudKit container configuration.

## Platform

1. Target modern iOS versions by default.
1. Use Swift 6.2 or later when available.
1. Use SwiftUI for the user interface.
1. Use Swift Concurrency for asynchronous work where appropriate.
1. Avoid UIKit unless a specific app requirement cannot be met cleanly with SwiftUI.
1. Configure a native launch screen for every app target, for example with `UILaunchScreen`, so iOS runs the app at the device native full-screen size instead of compatibility-scaled mode with black borders.

## Project Generation

1. Use XcodeGen to generate the Xcode project.
1. Keep project configuration in `project.yml`.
1. Treat the generated `.xcodeproj` as derived output unless the consuming project intentionally commits it.
1. Support template variables for at least:
   - app name
   - organization identifier
   - bundle identifier
   - deployment target
   - development team
   - supported platforms and devices

## Code Organization

1. Use Swift Package Manager to organize app code into modules.
1. Prefer feature-oriented folders and packages.
1. Keep shared code in focused modules instead of a large catch-all module.
1. Split different types into separate Swift files.
1. Do not introduce third-party frameworks by default.

## Suggested Modules

The template should provide a minimal modular structure that can be renamed or extended by the consuming app:

1. `App` - app entry point, scene setup, dependency wiring.
1. `Features` - SwiftUI feature screens and user flows.
1. `Models` - SwiftData models and shared domain types.
1. `Persistence` - SwiftData container setup, store configuration, migrations, and test stores.
1. `DesignSystem` - reusable SwiftUI components, colors, typography, spacing, and accessibility helpers.
1. `TestingSupport` - test fixtures, in-memory persistence helpers, and mock dependencies.

## Persistence

1. Use SwiftData as the default persistence layer.
1. Provide a production persistence configuration suitable for CloudKit/iCloud sync.
1. Provide local development configurations for:
   - in-memory storage
   - local persistent storage without iCloud
1. Make persistence setup injectable so previews, tests, and app targets can choose different stores.
1. Keep CloudKit-specific constraints visible in model design, including optional properties, relationship behavior, uniqueness limitations, and eventual consistency.
1. Add explicit relationship delete rules when models define relationships.

## CloudKit And iCloud

1. Support iCloud-backed SwiftData for release builds when the consuming app enables it.
1. Make the CloudKit container identifier configurable per app.
1. Do not hard-code a template app's container identifier.
1. Allow apps to disable iCloud for local builds, tests, and previews.

## SwiftUI

1. Use `NavigationStack` or `NavigationSplitView` for navigation.
1. Keep SwiftUI views small and composable.
1. Prefer native controls and platform conventions.
1. Support Dynamic Type, VoiceOver, Reduce Motion, and standard accessibility labels.
1. Avoid unnecessary global state; pass dependencies through clear boundaries.
1. Keep previews working with in-memory test data.

## Concurrency

1. Use structured concurrency with `async`/`await`.
1. Use actors or main-actor isolation where needed for shared mutable state and UI updates.
1. Avoid detached tasks unless there is a clear ownership and lifetime reason.
1. Keep persistence and UI updates on appropriate actors.

## Testing

1. Include unit test targets for package modules.
1. Include an app test target when useful for integration coverage.
1. Use in-memory SwiftData stores for model and persistence tests.
1. Keep test fixtures in `TestingSupport`.
1. Ensure the generated template can build and run tests without iCloud credentials.

## Template Deliverables

The template should generate or include:

1. `project.yml` for XcodeGen.
1. `Package.swift` for modular Swift Package code.
1. A minimal runnable SwiftUI app shell.
1. A SwiftData persistence bootstrap that supports production, local, preview, and test modes.
1. Example SwiftUI preview data using an in-memory store.
1. Basic unit tests proving the in-memory persistence setup works.
1. Documentation describing how to create a new app from the template.

## Non-Goals

1. Do not include product-specific features in the generic template.
1. Do not include a fixed data model beyond minimal examples needed to prove persistence works.
1. Do not require third-party dependencies by default.
1. Do not hard-code signing, team, bundle, or CloudKit identifiers.
