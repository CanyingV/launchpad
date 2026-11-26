# Launchpad for macOS

A lightweight SwiftUI launcher for macOS 14 and later. It scans `/Applications`, `/System/Applications`, Utilities, and the current user's `~/Applications`; search filters by app name or bundle ID, and selecting an app opens it through `NSWorkspace`.

## Build in GitHub Actions (no local Xcode required)

1. Create a GitHub repository and push this project to its `main` branch.
2. Open **Actions → Build macOS app → Run workflow**, or push a commit to `main` / `master`.
3. When the workflow finishes, open its run and download the `Launchpad-macOS` artifact.
4. Unzip it and move `Launchpad.app` to Applications.

Every workflow build includes a drag-to-install DMG and a ZIP artifact. Open the DMG and drag `Launchpad.app` onto the Applications shortcut. Pushing a tag such as `v1.0.0` also creates a GitHub Release with both files attached. The workflow generates the app icon and uses an ad-hoc signature; it does not require a paid Apple Developer account. macOS may show a first-open security prompt because the app is not Developer ID signed and notarized. For broader distribution, configure Developer ID signing and notarization secrets in GitHub Actions.

## Local build

Requires a Swift toolchain and macOS SDK that match. Run `swift build -c release` and launch `.build/release/Launchpad`.
