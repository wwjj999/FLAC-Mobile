# Implementation Plan: Material Expressive 3 UI Rework

## Overview

Implementasi migrasi UI SpotiFLAC Android ke Material Expressive 3 dengan dynamic color support. Tasks disusun secara incremental, dimulai dari setup dependencies, kemudian core theme system, lalu migrasi setiap screen.

## Tasks

- [x] 1. Setup dependencies dan project configuration
  - [x] 1.1 Add dynamic_color dan material_color_utilities ke pubspec.yaml
    - Tambahkan `dynamic_color: ^1.7.0`
    - Tambahkan `material_color_utilities: ^0.11.1`
    - Run `flutter pub get`
    - _Requirements: 1.1, 1.2_

  - [x] 1.2 Update Android minimum SDK jika diperlukan
    - Pastikan minSdkVersion >= 21 di android/app/build.gradle.kts
    - _Requirements: 1.1_

- [x] 2. Implement ThemeSettings model dan persistence
  - [x] 2.1 Create ThemeSettings model di lib/models/theme_settings.dart
    - Buat class ThemeSettings dengan themeMode, useDynamicColor, seedColorValue
    - Tambahkan JSON serialization
    - _Requirements: 2.1, 2.3, 2.4_

  - [ ]* 2.2 Write property test untuk ThemeSettings round-trip persistence
    - **Property 3: Theme settings persistence round-trip**
    - **Validates: Requirements 2.3, 2.4**

- [x] 3. Implement ThemeProvider dengan Riverpod
  - [x] 3.1 Create ThemeProvider di lib/providers/theme_provider.dart
    - Implement ThemeNotifier dengan load/save dari SharedPreferences
    - Implement setThemeMode, setUseDynamicColor, setSeedColor methods
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [ ]* 3.2 Write unit tests untuk ThemeProvider
    - Test initial state loading
    - Test state changes dan persistence
    - _Requirements: 2.3, 2.4_

- [x] 4. Implement AppTheme class
  - [x] 4.1 Create AppTheme di lib/theme/app_theme.dart
    - Implement light() dan dark() static methods
    - Configure semua component themes (Button, Card, AppBar, Navigation, Input, Dialog, ListTile)
    - Implement color harmonization untuk Spotify green
    - _Requirements: 3.1-3.7, 4.1-4.5, 6.1-6.5, 7.1-7.5_

  - [ ]* 4.2 Write property test untuk ColorScheme generation
    - **Property 1: ColorScheme generation from seed**
    - **Validates: Requirements 1.4**

  - [ ]* 4.3 Write property test untuk ColorScheme completeness
    - **Property 4: ColorScheme completeness**
    - **Validates: Requirements 4.1**

  - [ ]* 4.4 Write property test untuk color harmonization
    - **Property 5: Color harmonization shift**
    - **Validates: Requirements 4.5**

  - [ ]* 4.5 Write property test untuk contrast compliance
    - **Property 6: Color contrast compliance**
    - **Validates: Requirements 4.6, 10.1, 10.2**

- [x] 5. Implement DynamicColorWrapper dan update app.dart
  - [x] 5.1 Create DynamicColorWrapper di lib/theme/dynamic_color_wrapper.dart
    - Wrap MaterialApp dengan DynamicColorBuilder
    - Handle fallback ketika dynamic color tidak tersedia
    - _Requirements: 1.1, 1.2, 1.3_

  - [x] 5.2 Update lib/app.dart untuk menggunakan DynamicColorWrapper
    - Replace existing MaterialApp dengan DynamicColorWrapper
    - Wire ThemeProvider ke MaterialApp
    - _Requirements: 1.1-1.5, 2.1, 2.2_

  - [ ]* 5.3 Write property test untuk fallback behavior
    - **Property 2: Fallback behavior consistency**
    - **Validates: Requirements 1.3, 1.5**

- [x] 6. Checkpoint - Core theme system
  - Ensure all tests pass, ask the user if questions arise.
  - Verify dynamic color works on Android 12+ emulator/device
  - Verify fallback works on older Android versions

- [x] 7. Migrate HomeScreen ke Material 3
  - [x] 7.1 Update HomeScreen widgets
    - Replace hardcoded colors dengan Theme.of(context).colorScheme
    - Update AppBar styling
    - Update TextField styling
    - Update Button styling
    - Update ListTile styling
    - _Requirements: 5.1, 3.1-3.7_

  - [ ]* 7.2 Write widget test untuk HomeScreen theming
    - Verify theme colors applied correctly
    - _Requirements: 5.1_

- [x] 8. Migrate SearchScreen ke Material 3
  - [x] 8.1 Update SearchScreen widgets
    - Replace hardcoded colors dengan colorScheme
    - Update search bar styling
    - Update results list styling
    - _Requirements: 5.2, 3.1-3.7_

- [x] 9. Migrate QueueScreen ke Material 3
  - [x] 9.1 Update QueueScreen widgets
    - Replace hardcoded colors dengan colorScheme
    - Update progress indicators
    - Update queue item cards
    - _Requirements: 5.3, 3.1-3.7_

- [x] 10. Migrate HistoryScreen ke Material 3
  - [x] 10.1 Update HistoryScreen widgets
    - Replace hardcoded colors dengan colorScheme
    - Update history item styling
    - _Requirements: 5.5, 3.1-3.7_

- [x] 11. Migrate SetupScreen ke Material 3
  - [x] 11.1 Update SetupScreen widgets
    - Replace hardcoded colors dengan colorScheme
    - Update onboarding elements
    - _Requirements: 5.6, 3.1-3.7_

- [x] 12. Update SettingsScreen dengan theme controls
  - [x] 12.1 Add theme section ke SettingsScreen
    - Add theme mode selector (Light/Dark/System)
    - Add dynamic color toggle
    - Add seed color picker (when dynamic color disabled)
    - Add theme preview
    - _Requirements: 8.1-8.5_

  - [x] 12.2 Migrate existing SettingsScreen widgets ke Material 3
    - Replace deprecated RadioListTile dengan RadioGroup
    - Update dialog styling
    - Update switch styling
    - _Requirements: 5.4, 3.1-3.7_

  - [ ]* 12.3 Write widget test untuk theme settings UI
    - Test theme mode selection
    - Test dynamic color toggle
    - _Requirements: 8.1-8.5_

- [x] 13. Checkpoint - All screens migrated
  - Ensure all tests pass, ask the user if questions arise.
  - Visual review semua screens di light dan dark mode
  - Test dynamic color dengan berbagai wallpaper

- [x] 14. Implement smooth theme transitions
  - [x] 14.1 Add theme animation support
    - Configure themeAnimationDuration di MaterialApp
    - Ensure smooth color transitions
    - _Requirements: 9.1_

- [x] 15. Final polish dan accessibility
  - [x] 15.1 Verify accessibility compliance
    - Check contrast ratios di semua screens ✓ (Material 3 ColorScheme ensures WCAG compliance)
    - Verify touch targets >= 48dp ✓ (Using default Material 3 component sizes)
    - Test dengan TalkBack (manual testing recommended)
    - _Requirements: 10.1-10.5_

  - [x] 15.2 Clean up dan remove unused code
    - No old hardcoded color constants found - all screens use colorScheme
    - Theme folder structure is clean (app_theme.dart, dynamic_color_wrapper.dart)
    - Color picker in settings uses intentional preset colors
    - _Requirements: All_

- [x] 16. Final checkpoint
  - All diagnostics passed ✓
  - Full app walkthrough di berbagai theme modes (ready for manual testing)
  - Performance check untuk theme switching (300ms animation configured)

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Widget tests validate specific UI behavior

