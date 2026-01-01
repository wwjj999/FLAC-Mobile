# Implementation Plan: iOS Support

## Overview

Implementasi iOS support untuk SpotiFLAC dengan pendekatan: compile Go backend ke XCFramework, buat Swift bridge, konfigurasi iOS project, dan setup GitHub Actions untuk automated build.

## Tasks

- [x] 1. Setup iOS Project Structure
  - [x] 1.1 Create ios directory structure if not exists
    - Run `flutter create --platforms=ios .` if needed
    - Verify ios/ folder structure
    - _Requirements: 4.1, 4.2, 4.3, 4.4_
  
  - [x] 1.2 Configure Podfile for iOS dependencies
    - Set platform to iOS 14.0
    - Add ffmpeg-kit-ios-full pod
    - Configure post_install for deployment target
    - _Requirements: 4.1, 4.4_
  
  - [x] 1.3 Update Info.plist with required permissions
    - Add NSAppTransportSecurity for network access
    - Add UIFileSharingEnabled for Files app access
    - Add LSSupportsOpeningDocumentsInPlace
    - _Requirements: 4.2, 3.2_

- [x] 2. Go Backend iOS Compilation
  - [x] 2.1 Create build script for iOS XCFramework
    - Create `build_ios.sh` script
    - Install gomobile if not present
    - Compile with `gomobile bind -target=ios`
    - Output to `ios/Frameworks/Gobackend.xcframework`
    - _Requirements: 1.1, 1.2, 1.4_
  
  - [x] 2.2 Update Go backend for iOS compatibility
    - Review exports.go for iOS-specific issues
    - Ensure all exported functions work on iOS
    - Test compilation locally (requires Mac) or via CI
    - _Requirements: 1.3_

- [x] 3. iOS Platform Bridge Implementation
  - [x] 3.1 Create AppDelegate.swift with MethodChannel handler
    - Import Gobackend framework
    - Setup FlutterMethodChannel with same name as Android
    - Implement setMethodCallHandler
    - _Requirements: 2.1_
  
  - [x] 3.2 Implement all method handlers in Swift
    - parseSpotifyUrl
    - getSpotifyMetadata
    - searchSpotify
    - checkAvailability
    - downloadTrack
    - downloadWithFallback
    - getDownloadProgress
    - setDownloadDirectory
    - checkDuplicate
    - buildFilename
    - sanitizeFilename
    - fetchLyrics
    - getLyricsLRC
    - embedLyricsToFile
    - _Requirements: 2.2, 2.3, 2.4_
  
  - [x] 3.3 Implement error handling in Swift bridge
    - Catch Go errors and convert to FlutterError
    - Handle nil/null cases
    - Async dispatch for non-blocking calls
    - _Requirements: 2.5_

- [x] 4. Cross-Platform Dart Code Updates
  - [x] 4.1 Update download_queue_provider.dart for iOS paths
    - Add Platform.isIOS check in _initOutputDir()
    - Use Documents directory for iOS
    - Keep existing Android logic
    - _Requirements: 3.1, 3.4, 5.2_
  
  - [x] 4.2 Update FFmpegService for iOS compatibility
    - Verify ffmpeg_kit_flutter_new works on iOS
    - Test audio conversion on iOS
    - _Requirements: 5.1_
  
  - [x] 4.3 Review and update any platform-specific code
    - Check for Platform.isAndroid assumptions
    - Add Platform.isIOS alternatives where needed
    - Updated setup_screen.dart for iOS (no storage permission needed)
    - _Requirements: 5.1, 5.3_

- [x] 5. iOS App Icon and Launch Screen
  - [x] 5.1 Generate iOS app icons from icon.png
    - Update flutter_launcher_icons config for iOS
    - Run `dart run flutter_launcher_icons`
    - Verify all icon sizes generated
    - _Requirements: 7.1, 7.2, 7.4_
  
  - [x] 5.2 Create iOS launch screen
    - Configure LaunchScreen.storyboard
    - Match app theme colors (dark: #1a1a2e)
    - _Requirements: 7.3_

- [x] 6. GitHub Actions iOS Build Workflow
  - [x] 6.1 Create .github/workflows/ios-build.yml
    - Use macos-latest runner
    - Install Flutter, Go, gomobile
    - Compile Go backend to XCFramework
    - Build iOS app (no signing for now)
    - Upload IPA as artifact
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_
  
  - [x] 6.2 Add error handling and notifications
    - Clear error messages on failure
    - Build status badge for README
    - _Requirements: 6.6_

- [x] 7. Checkpoint - Verify iOS Build
  - All files created and verified
  - No diagnostics errors
  - Ready for GitHub Actions testing

- [x] 8. Documentation
  - [x] 8.1 Update README with iOS build instructions
    - Prerequisites (Mac for local build, or use CI)
    - Build commands
    - Known limitations
    - _Requirements: N/A_

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Local iOS testing requires macOS with Xcode
- GitHub Actions provides free macOS runners for CI/CD
- Apple Developer Account ($99/year) needed for TestFlight distribution
- Some tasks (2.2, 3.1-3.3) require macOS to test locally, but can be developed on Windows and tested via CI
