# Gestures

macOS menu bar app that maps trackpad gestures to keyboard shortcuts.

## Supported Gestures

| Gesture                   | Description                                              | Default Action |
| ------------------------- | -------------------------------------------------------- | -------------- |
| Three-Finger Tap          | Three fingers touch briefly with minimal movement        | Middle click   |
| Three-Finger Swipe Down   | Three fingers swipe downward together                    | Cmd+W          |
| Two-Finger Tip-Tap Left   | One finger anchors while a second taps to its left side  | Opt+Cmd+Left   |
| Two-Finger Tip-Tap Right  | One finger anchors while a second taps to its right      | Opt+Cmd+Right  |
| Three-Finger Tip-Tap Left | Two fingers anchor while a third taps on their left side | Cmd+R          |

Each gesture can be enabled or disabled, remapped to a keyboard shortcut or middle click, and configured with optional haptic feedback.

## Features

- Menu bar app, no dock icon
- Remap gestures to keyboard shortcuts or middle click
- Per-gesture haptic feedback
- Launch at login
- Click suppression during gesture recognition
- Debug logging

## Requirements

- macOS 26.0+
- Accessibility permission (the app will prompt on first launch)

## Install

```bash
scripts/install-app.sh
```

This builds the app with SwiftPM, creates a signed `.app` bundle, installs it to `~/Applications`, and verifies the result.

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

## Getting Started

1. Install the app with `scripts/install-app.sh`.
2. Launch `Gestures.app` from `~/Applications`.
3. Open the menu bar item and grant Accessibility access when prompted.
4. Confirm that the status reads `Capture Running`.
5. Open `Settings…` to change gesture mappings or enable haptic feedback.

## Using the App

- The menu bar item shows capture status and Accessibility status.
- `Settings → General` contains status, Accessibility controls, and launch-at-login.
- `Settings → Gestures` contains per-gesture settings.
- `Settings → Advanced` contains debug mode and log access.

## Troubleshooting

- If gestures do not trigger actions, confirm that Accessibility access is granted and then use `Restart Capture`.
- If the menu bar item says capture is stopped, use `Restart Capture` and recheck Accessibility status in `Settings → General`.
- If gesture detection seems inconsistent, enable debug mode in `Settings → Advanced`, reproduce the issue, and inspect the log at `~/Library/Application Support/Gestures/Logs/debug.log`.
- Launch at login is only available in the bundled `.app` build, not when running the executable directly through `swift run`.

## Development

```bash
swift build
swift test
swift run GesturesApp
```

The app uses the private `MultitouchSupport.framework` for raw trackpad data, so it is intended for direct distribution rather than the App Store.

## License

MIT, see [LICENSE](LICENSE) for details.
