# Personal Toolbox for TrollStore

This repository is a minimal SwiftUI iOS app that can be edited on Windows and built on GitHub Actions.

## Why this layout

The repository does not commit an `.xcodeproj`. Instead it uses `project.yml` plus XcodeGen to generate the project on the macOS runner.

That matters because `xcodebuild` works against an Xcode project or scheme, and XcodeGen can generate that project on CI from plain files.

## Files

- `Calculator/CalculatorApp.swift`: SwiftUI app entry point
- `Calculator/ContentView.swift`: personal toolbox UI and logic
- `project.yml`: XcodeGen spec used to generate `Calculator.xcodeproj`
- `scripts/package-ipa.sh`: builds the app for `iphoneos` and packages an IPA
- `.github/workflows/build.yml`: manual GitHub Actions workflow

## GitHub usage

1. Create a public GitHub repository.
2. Upload everything in this folder.
3. Open the `Actions` tab.
4. Run `Build TrollStore IPA`.
5. Download the `Calculator-TrollStore` artifact.
6. Extract it and send `Calculator.ipa` to your iPhone.
7. Open the IPA with TrollStore and install it.

## Notes

- This is for personal testing with TrollStore, not App Store distribution.
- If you later want camera, files, network, or location features, the project can be extended from here.
- If the GitHub macOS image changes and a build breaks, pinning the runner or Xcode version is the first thing to check.
