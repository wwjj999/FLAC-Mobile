# Design Document: iOS Support

## Overview

Dokumen ini menjelaskan arsitektur dan implementasi untuk menambahkan dukungan iOS ke aplikasi SpotiFLAC. Pendekatan utama adalah menggunakan gomobile untuk compile Go backend ke XCFramework, kemudian membuat Swift bridge yang menghubungkan Flutter dengan Go backend melalui MethodChannel.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter App (Dart)                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                   PlatformBridge                     │    │
│  │              (lib/services/platform_bridge.dart)     │    │
│  └─────────────────────┬───────────────────────────────┘    │
│                        │ MethodChannel                       │
│                        ▼                                     │
├─────────────────────────────────────────────────────────────┤
│                    Platform Layer                            │
│  ┌──────────────────┐         ┌──────────────────────┐      │
│  │   Android (Kotlin)│         │    iOS (Swift)       │      │
│  │   MainActivity.kt │         │   AppDelegate.swift  │      │
│  └────────┬─────────┘         └──────────┬───────────┘      │
│           │                              │                   │
│           ▼                              ▼                   │
│  ┌──────────────────┐         ┌──────────────────────┐      │
│  │  gobackend.aar   │         │ Gobackend.xcframework│      │
│  │  (Android lib)   │         │    (iOS lib)         │      │
│  └──────────────────┘         └──────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. Go Backend XCFramework

Go backend akan di-compile menggunakan `gomobile bind` dengan target iOS:

```bash
# Build for iOS device and simulator
gomobile bind -target=ios -o Gobackend.xcframework ./gobackend
```

Output: `Gobackend.xcframework` yang berisi:
- `ios-arm64` - untuk iPhone/iPad fisik
- `ios-arm64_x86_64-simulator` - untuk iOS Simulator

### 2. iOS Bridge (AppDelegate.swift)

```swift
import UIKit
import Flutter
import Gobackend  // Import Go framework

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
            name: "com.zarz.spotiflac/backend",
            binaryMessenger: controller.binaryMessenger
        )
        
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call: call, result: result)
        }
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let response = try self.invokeGoMethod(call: call)
                DispatchQueue.main.async {
                    result(response)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func invokeGoMethod(call: FlutterMethodCall) throws -> Any? {
        switch call.method {
        case "parseSpotifyUrl":
            let args = call.arguments as! [String: Any]
            let url = args["url"] as! String
            var error: NSError?
            let response = GobackendParseSpotifyURL(url, &error)
            if let error = error { throw error }
            return response
            
        case "getSpotifyMetadata":
            let args = call.arguments as! [String: Any]
            let url = args["url"] as! String
            var error: NSError?
            let response = GobackendGetSpotifyMetadata(url, &error)
            if let error = error { throw error }
            return response
            
        // ... other methods
        
        default:
            throw NSError(domain: "SpotiFLAC", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Method not implemented"])
        }
    }
}
```

### 3. iOS File Paths

iOS menggunakan sandbox, jadi file paths berbeda dari Android:

```dart
// In download_queue_provider.dart - update _initOutputDir()
Future<void> _initOutputDir() async {
  if (state.outputDir.isEmpty) {
    if (Platform.isIOS) {
      // iOS: Use Documents directory (accessible via Files app)
      final dir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${dir.path}/SpotiFLAC');
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }
      state = state.copyWith(outputDir: musicDir.path);
    } else {
      // Android: existing logic
      // ...
    }
  }
}
```

### 4. Podfile Configuration

```ruby
platform :ios, '14.0'

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  
  # FFmpeg for audio conversion
  pod 'ffmpeg-kit-ios-full', '~> 6.0'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
    end
  end
end
```

### 5. Info.plist Permissions

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
<key>UIFileSharingEnabled</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
<key>UISupportsDocumentBrowser</key>
<true/>
```

## Data Models

Tidak ada perubahan data model - semua model Dart existing akan bekerja di iOS.

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do.*

### Property 1: API Function Parity
*For any* exported function in the Android Go backend (AAR), the iOS Go backend (XCFramework) SHALL expose an equivalent function with the same signature and behavior.
**Validates: Requirements 1.3**

### Property 2: Method Channel Coverage
*For any* method name defined in PlatformBridge.dart, the iOS bridge (AppDelegate.swift) SHALL have a corresponding handler that invokes the appropriate Go function.
**Validates: Requirements 2.2**

### Property 3: Method Call Round-Trip
*For any* valid method call from Flutter with valid parameters, calling the method on iOS SHALL return a result equivalent to calling the same method on Android.
**Validates: Requirements 2.3, 2.4, 5.1**

### Property 4: iOS File Path Validity
*For any* downloaded file on iOS, the file path SHALL be within the app's Documents directory and accessible via the Files app.
**Validates: Requirements 3.1**

### Property 5: Platform-Appropriate Paths
*For any* file operation, the app SHALL use Documents directory on iOS and external storage on Android, with both paths being valid for their respective platforms.
**Validates: Requirements 5.2**

### Property 6: iOS Icon Size Completeness
*For any* required iOS app icon size (20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024), the Assets.xcassets SHALL contain an icon of that exact size.
**Validates: Requirements 7.2**

## Error Handling

### Go Backend Errors
- Go functions return `(string, error)` tuple
- Swift bridge catches errors and converts to `FlutterError`
- Flutter receives error via MethodChannel error callback

### Network Errors
- Same handling as Android - Go backend handles retries
- Timeout errors propagated to Flutter

### File System Errors
- iOS sandbox violations caught and reported
- Permission errors handled gracefully

## Testing Strategy

### Unit Tests
- Test Swift bridge method routing
- Test file path generation for iOS
- Test error conversion from Go to Flutter

### Property-Based Tests
- **Property 1**: Compare exported symbols between AAR and XCFramework
- **Property 2**: Parse PlatformBridge.dart and verify all methods exist in AppDelegate.swift
- **Property 3**: Run same test cases on both platforms and compare results
- **Property 6**: Enumerate Assets.xcassets and verify all required sizes present

### Integration Tests
- End-to-end download test on iOS Simulator
- File accessibility test via Files app
- Cross-platform behavior comparison

### CI/CD Testing
- GitHub Actions workflow validates build succeeds
- Artifact upload verification
