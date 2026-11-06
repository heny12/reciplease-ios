# Agent instructions

Before you finish a change in this repo, run:

```bash
./scripts/verify.sh
```

`swiftc -parse` is not enough. It only builds a syntax tree. It does not resolve names, check `Codable` synthesis, match method signatures, or apply the Xcode target's Swift settings (`SWIFT_VERSION`, `SWIFT_DEFAULT_ACTOR_ISOLATION`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`). A file can parse cleanly and still fail `swift build` or `xcodebuild` — `SavedAppData` missing `CodingKeys` was that kind of failure.

`./scripts/verify.sh` does the real checks:

1. `swift build` and `swift test` typecheck the Swift package (domain, models, persistence, and the API clients) and run the unit tests.
2. SwiftLint, using a pinned Linux binary cached in `.cache/tools` when it is not already installed.
3. `swiftc -parse` only for Swift files the package excludes (SwiftUI screens and Apple-only services).
4. A `project.pbxproj` integrity check. App sources belong to the target through `PBXFileSystemSynchronizedRootGroup`, not a hand-written `PBXSourcesBuildPhase` file list.
5. When `xcodebuild` exists, an unsigned `generic/platform=iOS Simulator` build of the `PantryPal` scheme. That is the only check that typechecks SwiftUI against the iOS SDK.

Do not report the iOS app as compiled unless that `xcodebuild` step actually ran.
