# Requirements Document

## Introduction

Menambahkan dukungan iOS untuk aplikasi SpotiFLAC yang saat ini hanya berjalan di Android. Fitur ini akan memungkinkan aplikasi berjalan di iPhone dan iPad dengan fungsionalitas yang sama seperti versi Android, termasuk download musik dari Tidal, Qobuz, dan Amazon Music.

## Glossary

- **Go_Backend**: Library Go yang berisi logic download dan API integration, di-compile menggunakan gomobile
- **Platform_Bridge**: Layer Dart yang berkomunikasi dengan native code via MethodChannel
- **iOS_Bridge**: Swift code yang menghubungkan Flutter dengan Go backend di iOS
- **XCFramework**: Format distribusi library untuk iOS yang mendukung multiple architectures
- **Podfile**: File konfigurasi CocoaPods untuk iOS dependencies
- **GitHub_Actions**: CI/CD service untuk build iOS app di macOS runner

## Requirements

### Requirement 1: Go Backend iOS Compilation

**User Story:** As a developer, I want to compile the Go backend for iOS, so that the download functionality works on iPhone/iPad.

#### Acceptance Criteria

1. THE Build_System SHALL compile Go backend to XCFramework format for iOS (arm64)
2. THE Build_System SHALL compile Go backend to XCFramework format for iOS Simulator (arm64, x86_64)
3. THE XCFramework SHALL expose the same API functions as the Android AAR
4. WHEN the XCFramework is built, THE Build_System SHALL place it in `ios/Frameworks/` directory

### Requirement 2: iOS Platform Bridge

**User Story:** As a developer, I want a Swift bridge that connects Flutter to Go backend, so that the existing Dart code works on iOS.

#### Acceptance Criteria

1. THE iOS_Bridge SHALL implement MethodChannel handler in AppDelegate.swift
2. THE iOS_Bridge SHALL handle all methods defined in PlatformBridge.dart
3. WHEN a method is called from Flutter, THE iOS_Bridge SHALL invoke the corresponding Go function
4. WHEN Go function returns, THE iOS_Bridge SHALL pass the result back to Flutter
5. IF an error occurs in Go backend, THEN THE iOS_Bridge SHALL return error to Flutter via MethodChannel

### Requirement 3: iOS File System Integration

**User Story:** As a user, I want downloaded files saved to accessible location on iOS, so that I can play them in other apps.

#### Acceptance Criteria

1. THE App SHALL save downloaded files to Documents directory on iOS
2. THE App SHALL request appropriate file access permissions
3. WHEN a file is downloaded, THE App SHALL make it accessible via Files app
4. THE App SHALL handle iOS sandbox restrictions appropriately

### Requirement 4: iOS Project Configuration

**User Story:** As a developer, I want proper iOS project setup, so that the app can be built and distributed.

#### Acceptance Criteria

1. THE Podfile SHALL include FFmpeg dependency for audio conversion
2. THE Info.plist SHALL declare required permissions (network, file access)
3. THE iOS project SHALL have proper bundle identifier and signing configuration
4. THE iOS project SHALL support iOS 14.0 and above

### Requirement 5: Cross-Platform Dart Code Compatibility

**User Story:** As a developer, I want the existing Dart code to work on both platforms, so that I don't need to maintain separate codebases.

#### Acceptance Criteria

1. THE PlatformBridge SHALL work identically on Android and iOS
2. THE App SHALL use platform-appropriate file paths automatically
3. WHEN running on iOS, THE App SHALL use iOS-specific UI adaptations where needed
4. THE Theme_System SHALL work on iOS with Cupertino-style adaptations if needed

### Requirement 6: GitHub Actions iOS Build

**User Story:** As a developer, I want automated iOS builds via GitHub Actions, so that I can build iOS app without owning a Mac.

#### Acceptance Criteria

1. THE GitHub_Actions workflow SHALL run on macOS runner
2. THE Workflow SHALL install Flutter, Go, and gomobile
3. THE Workflow SHALL compile Go backend to XCFramework
4. THE Workflow SHALL build iOS app (IPA file)
5. THE Workflow SHALL upload build artifacts for download
6. IF build fails, THEN THE Workflow SHALL report clear error messages

### Requirement 7: iOS App Icon and Launch Screen

**User Story:** As a user, I want the iOS app to have proper branding, so that it looks professional on my device.

#### Acceptance Criteria

1. THE App SHALL use the same logo as Android version for app icon
2. THE App SHALL have proper iOS app icon sizes (all required sizes)
3. THE App SHALL have a launch screen matching the app theme
4. THE App icon SHALL support iOS adaptive icon format
