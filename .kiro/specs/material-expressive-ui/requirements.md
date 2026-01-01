# Requirements Document

## Introduction

Dokumen ini mendefinisikan requirements untuk merework seluruh tampilan aplikasi SpotiFLAC Android menjadi Material Expressive 3 (Material You). Fitur utama adalah dynamic theming yang mengekstrak warna dari wallpaper pengguna untuk menghasilkan color scheme yang personal dan konsisten di seluruh aplikasi.

## Glossary

- **Dynamic_Color_System**: Sistem yang mengekstrak warna dominan dari wallpaper pengguna dan menghasilkan ColorScheme Material 3 secara otomatis
- **Theme_Provider**: Provider Riverpod yang mengelola state tema aplikasi termasuk mode (light/dark/system) dan dynamic color
- **Color_Scheme**: Kumpulan warna Material 3 yang dihasilkan dari seed color atau wallpaper
- **Expressive_Component**: Widget UI yang menggunakan Material 3 design tokens dan mendukung dynamic theming
- **Surface_Tint**: Efek warna overlay pada surface berdasarkan elevation
- **Harmonized_Color**: Warna custom yang diselaraskan dengan dynamic color scheme

## Requirements

### Requirement 1: Dynamic Color Integration

**User Story:** As a user, I want the app to automatically adapt its colors based on my wallpaper, so that the app feels personalized and matches my device aesthetic.

#### Acceptance Criteria

1. WHEN the app launches on Android 12+, THE Dynamic_Color_System SHALL extract colors from the device wallpaper
2. WHEN the wallpaper changes, THE Dynamic_Color_System SHALL update the app's color scheme automatically
3. WHEN running on Android versions below 12, THE Dynamic_Color_System SHALL use a fallback seed color (Spotify green #1DB954)
4. THE Color_Scheme SHALL generate both light and dark variants from the extracted/seed color
5. WHEN dynamic color is disabled in settings, THE Theme_Provider SHALL use the fallback seed color instead

### Requirement 2: Theme Mode Management

**User Story:** As a user, I want to choose between light, dark, or system-following theme modes, so that I can control the app's appearance.

#### Acceptance Criteria

1. THE Theme_Provider SHALL support three theme modes: light, dark, and system
2. WHEN theme mode is set to system, THE Theme_Provider SHALL follow the device's dark mode setting
3. WHEN the user changes theme mode, THE Theme_Provider SHALL persist the preference to local storage
4. WHEN the app restarts, THE Theme_Provider SHALL restore the previously selected theme mode
5. THE Theme_Provider SHALL apply theme changes immediately without requiring app restart

### Requirement 3: Material 3 Component Migration

**User Story:** As a user, I want the app to use modern Material 3 components, so that the UI feels contemporary and consistent.

#### Acceptance Criteria

1. THE Expressive_Component library SHALL replace all existing widgets with Material 3 equivalents
2. WHEN displaying buttons, THE Expressive_Component SHALL use FilledButton, OutlinedButton, or TextButton based on emphasis
3. WHEN displaying cards, THE Expressive_Component SHALL use Card with proper surface tint and elevation
4. WHEN displaying lists, THE Expressive_Component SHALL use ListTile with Material 3 styling
5. WHEN displaying navigation, THE Expressive_Component SHALL use NavigationBar (bottom) or NavigationRail (tablet)
6. WHEN displaying dialogs, THE Expressive_Component SHALL use Dialog with Material 3 shape and colors
7. WHEN displaying text fields, THE Expressive_Component SHALL use TextField with Material 3 decoration

### Requirement 4: Color Scheme Application

**User Story:** As a user, I want consistent colors throughout the app, so that the visual experience is cohesive.

#### Acceptance Criteria

1. THE Color_Scheme SHALL define primary, secondary, tertiary, error, and surface color roles
2. WHEN displaying primary actions, THE Expressive_Component SHALL use colorScheme.primary
3. WHEN displaying surfaces, THE Expressive_Component SHALL use colorScheme.surface with appropriate tint
4. WHEN displaying text, THE Expressive_Component SHALL use colorScheme.onSurface or appropriate "on" color
5. WHEN displaying the Spotify green accent, THE Harmonized_Color SHALL harmonize it with the dynamic scheme
6. THE Color_Scheme SHALL maintain WCAG 2.1 AA contrast ratios for text readability

### Requirement 5: Screen-Specific Theming

**User Story:** As a user, I want each screen to properly utilize the theme, so that the entire app looks unified.

#### Acceptance Criteria

1. WHEN displaying HomeScreen, THE Expressive_Component SHALL apply theme to AppBar, search field, track list, and buttons
2. WHEN displaying SearchScreen, THE Expressive_Component SHALL apply theme to search bar and results list
3. WHEN displaying QueueScreen, THE Expressive_Component SHALL apply theme to queue items and progress indicators
4. WHEN displaying SettingsScreen, THE Expressive_Component SHALL apply theme to all settings tiles and dialogs
5. WHEN displaying HistoryScreen, THE Expressive_Component SHALL apply theme to history items
6. WHEN displaying SetupScreen, THE Expressive_Component SHALL apply theme to onboarding elements

### Requirement 6: Typography System

**User Story:** As a user, I want readable and consistent text throughout the app, so that content is easy to consume.

#### Acceptance Criteria

1. THE Expressive_Component SHALL use Material 3 typography scale (displayLarge through labelSmall)
2. WHEN displaying titles, THE Expressive_Component SHALL use titleLarge or titleMedium
3. WHEN displaying body text, THE Expressive_Component SHALL use bodyLarge or bodyMedium
4. WHEN displaying labels, THE Expressive_Component SHALL use labelLarge or labelMedium
5. THE Typography system SHALL support dynamic type scaling based on device settings

### Requirement 7: Shape System

**User Story:** As a user, I want consistent rounded corners and shapes, so that the UI feels polished.

#### Acceptance Criteria

1. THE Expressive_Component SHALL use Material 3 shape tokens (extraSmall through extraLarge)
2. WHEN displaying cards, THE Expressive_Component SHALL use medium rounded corners (12dp)
3. WHEN displaying buttons, THE Expressive_Component SHALL use full rounded corners for FABs and medium for others
4. WHEN displaying dialogs, THE Expressive_Component SHALL use extraLarge rounded corners (28dp)
5. WHEN displaying chips and badges, THE Expressive_Component SHALL use small rounded corners (8dp)

### Requirement 8: Settings UI for Theme Control

**User Story:** As a user, I want to control theme settings, so that I can customize my experience.

#### Acceptance Criteria

1. THE SettingsScreen SHALL display a theme section with mode selection (Light/Dark/System)
2. THE SettingsScreen SHALL display a toggle for enabling/disabling dynamic color
3. WHEN dynamic color is disabled, THE SettingsScreen SHALL show a color picker for manual seed color selection
4. WHEN the user selects a theme option, THE Theme_Provider SHALL apply changes immediately
5. THE SettingsScreen SHALL preview the current theme colors

### Requirement 9: Transition and Animation

**User Story:** As a user, I want smooth transitions when theme changes, so that the experience feels polished.

#### Acceptance Criteria

1. WHEN theme mode changes, THE Theme_Provider SHALL animate the color transition smoothly
2. WHEN navigating between screens, THE Expressive_Component SHALL use Material 3 motion patterns
3. WHEN displaying loading states, THE Expressive_Component SHALL use CircularProgressIndicator with theme colors
4. WHEN displaying state changes, THE Expressive_Component SHALL use appropriate duration curves

### Requirement 10: Accessibility Compliance

**User Story:** As a user with accessibility needs, I want the app to remain usable regardless of theme, so that I can use the app comfortably.

#### Acceptance Criteria

1. THE Color_Scheme SHALL maintain minimum 4.5:1 contrast ratio for normal text
2. THE Color_Scheme SHALL maintain minimum 3:1 contrast ratio for large text and icons
3. WHEN high contrast mode is enabled on device, THE Theme_Provider SHALL increase contrast levels
4. THE Expressive_Component SHALL support semantic labels for screen readers
5. THE Expressive_Component SHALL support touch targets of minimum 48dp

