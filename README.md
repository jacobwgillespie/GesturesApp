# Gestures

Minimal macOS menu bar utility that maps trackpad gestures to keyboard shortcuts.

## Supported Gestures

| Gesture                  | Description                                             | Default Action       |
| ------------------------ | ------------------------------------------------------- | -------------------- |
| Three-Finger Tap         | Three fingers touch briefly with minimal movement       | Middle click         |
| Three-Finger Swipe Down  | Three fingers swipe downward together                   | Cmd+W                |
| Two-Finger Tip-Tap Left  | One finger anchors while a second taps to its left side | Opt+Cmd+Left         |
| Two-Finger Tip-Tap Right | One finger anchors while a second taps to its right     | Opt+Cmd+Right        |
| Three-Finger Tip-Tap Left | Two fingers anchor while a third taps on their left side | Cmd+R              |

Each gesture can be individually enabled/disabled and remapped to a custom keyboard shortcut or middle click via the Settings window.

## Requirements

- macOS 26.0+
- Accessibility permission (the app will prompt on first launch)

## Install

```bash
scripts/install-app.sh
```

This builds the app with SwiftPM, creates a signed `.app` bundle, and installs it to `~/Applications`.

Options:

```
--debug               Build the debug configuration
--release             Build the release configuration (default)
--install-dir PATH    Install destination (default: ~/Applications)
```

Environment overrides:

```
BUNDLE_ID             Bundle identifier (default: com.jacobwgillespie.gestures)
INSTALL_DIR           Install destination
CONFIGURATION         debug or release
SIGNING_IDENTITY      Code signing identity (default: auto-detect, falls back to ad-hoc)
```

## Development

```bash
swift build
swift test
swift run GesturesApp
```

The app uses the private `MultitouchSupport.framework` for raw trackpad data, so it is intended for direct distribution rather than the App Store.
