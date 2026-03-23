# Gestures

Minimal macOS menu bar utility for mapping trackpad gestures to keyboard shortcuts.

## Development

```bash
swift build
swift test
swift run GesturesApp
scripts/install-app.sh
```

The app uses the private `MultitouchSupport.framework`, so it is intended for direct distribution rather than the App Store.
