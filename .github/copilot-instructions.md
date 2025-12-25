# Beacon SOS Emergency Signal App - AI Agent Instructions

## Project Overview

**Beacon** is a Flutter-based mobile emergency SOS application designed for offline-capable emergency communication. The app enables users to broadcast distress signals via shake/button activation, SMS alerts, Bluetooth broadcasting, and GPS sharing.

**Target platforms:** Android

**Current stage:** Early development with boilerplate Flutter structure. Core feature modules need implementation.

---

## Architecture & Components

### Module Structure (from project spec)
Per the project requirements document, Beacon is organized around these core modules:

- **SOS Manager**: Handles shake detection and manual SOS activation
- **Distress Package Generator**: Creates payload containing GPS, timestamp, contact info, evidence
- **Communication Module**: SMS, Bluetooth, call initiation
- **BlackBox Storage**: Local encrypted storage of distress events for evidence retrieval
- **Contacts Manager**: Emergency contact management
- **Siren Module**: Alert audio playback

### Data Design
- **Database**: SQLite for local contact/event storage
- **Local Storage**: Evidence blackbox using filesystem
- **Location**: GPS integration for real-time tracking
- **Communication**: Direct SMS and Bluetooth (no backend required for core functionality)

### Current Codebase State
- `lib/main.dart` contains a standard Flutter boilerplate (counter app)
- `test/widget_test.dart` demonstrates basic widget test pattern
- No feature modules implemented yet
- Project uses `flutter_lints` for code analysis

---

## Development Workflow

### Build & Run Commands
```bash
# Get dependencies
flutter pub get

# Analyze code
flutter analyze

# Run tests
flutter test
# or for a specific test file
flutter test test/widget_test.dart

# Run app (default to debug on connected device)
flutter run

# Build for specific platform
flutter build apk    # Android
flutter build ios    # iOS (macOS required)
flutter build windows
flutter build macos
flutter build linux
```

### Hot Reload Workflow
- **Hot Reload** (Ctrl+S / Cmd+S): Preserves app state; fastest for UI/logic changes
- **Hot Restart** (Ctrl+Shift+F5): Full app restart if state needs reset
- Use for iterating on widgets and business logic

### Testing
- Widget tests in `test/` use `WidgetTester` from `flutter_test`
- Pattern: `tester.pumpWidget()`, `find.*()`, `expect()`
- Example: `test/widget_test.dart` shows counter app testing

---

## Code Patterns & Conventions

### Widget Structure
- **Stateless widgets**: Use for pure UI components with no mutable state
- **Stateful widgets**: Split into `MyWidget extends StatefulWidget` + `_MyWidgetState extends State<MyWidget>`
- **Naming**: Private state classes prefixed with `_` (e.g., `_MyHomePageState`)

### State Management (Flutter Standard)
- Use `setState()` for simple state updates within a StatefulWidget
- For cross-component state, consider `Provider` package (not yet added; see `pubspec.yaml`)
- Avoid direct widget rebuilds; always call `setState()` for state changes

### Build Method Pattern
- Keep build methods focused; extract complex widgets into separate widget classes
- Use `const` constructors where possible for performance
- Structure: Scaffold → AppBar/body, Column/Row children, etc.

### Async/Await Pattern
```dart
Future<void> myAsyncFunction() async {
  try {
    final result = await someAsyncCall();
    // handle result
  } catch (e) {
    // handle error
  }
}
```

---

## Dependencies & Integration Points

### Current Dependencies
- `flutter` (SDK ^3.9.2)
- `cupertino_icons: ^1.0.8` (iOS-style icons)
- `flutter_lints: ^5.0.0` (dev)

### Required (Not Yet Added)
Per requirements, add these when implementing features:
- **Shake detection**: `sensors_plus` or `shake` package
- **GPS**: `geolocator` or `location`
- **SMS**: `flutter_sms` or platform channels
- **Bluetooth**: `flutter_blue` or `flutter_blue_plus`
- **Audio/Siren**: `audioplayers` or `just_audio`
- **SQLite**: `sqflite`
- **State management**: `provider`, `riverpod`, or `get_it` (recommend `provider` for simplicity)

### Platform-Specific Files
- **Android**: `android/app/build.gradle.kts` (Kotlin-based build)
- **iOS**: `ios/Runner/Info.plist` (permissions configuration)
- **Windows/Linux/macOS**: Native runner configuration in respective directories

---

## Code Analysis & Linting

### Lint Configuration
- Uses `package:flutter_lints/flutter.yaml` from `analysis_options.yaml`
- Run analysis: `flutter analyze`
- Common lint rules: prefer const constructors, avoid print in production, handle missing cases

### Code Format
- Use `dart format .` to auto-format (though Flutter IDE plugins typically handle this)
- 2-space indentation standard in Dart

---

## Key File Locations

| Purpose | Location |
|---------|----------|
| App entry point | `lib/main.dart` |
| Test examples | `test/widget_test.dart` |
| Dependencies | `pubspec.yaml` |
| Linting rules | `analysis_options.yaml` |
| Project spec | Attachment: "11_Oct Beacon Master Draft.md" |

---

## Important Notes for AI Development

1. **Boilerplate Stage**: The codebase is currently minimal (counter app). Plan to scaffold modules according to the spec.

2. **Offline-First**: Beacon must work without internet. All critical features (SOS generation, SMS, Bluetooth) must function locally. Design data flows accordingly.

3. **Permissions**: iOS and Android require explicit permission grants (GPS, SMS, Bluetooth, microphone for siren). Handle gracefully with user prompts.

4. **Evidence Preservation**: BlackBox must survive app crashes. Use secure local storage (SQLite + file encryption) for critical events.

5. **Real-Time Communication**: Shake detection must be responsive. Use platform-specific optimizations and avoid blocking the main thread.

6. **Testing Strategy**: Widget tests for UI; unit tests for business logic (distress package generation, contact filtering). Mock sensors and communication for testing.

---

## References

- Flutter docs: https://flutter.dev
- Dart language: https://dart.dev
- Project specification: 11_Oct Beacon Master Draft.md
