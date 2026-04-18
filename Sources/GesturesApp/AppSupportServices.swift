import AppKit
import Foundation
import GesturesCore
import ServiceManagement
import SwiftUI

struct AccessibilityAccessController {
    func refreshStatus() -> Bool {
        PermissionsManager.isAccessibilityTrusted(prompt: false)
    }

    func requestAccess() -> Bool {
        PermissionsManager.isAccessibilityTrusted(prompt: true)
    }

    func openSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
        ]

        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}

struct LaunchAtLoginController {
    var isSupported: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    func refreshStatus() -> Bool {
        guard isSupported else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ isEnabled: Bool) throws {
        guard isSupported else {
            throw LaunchAtLoginError.unsupported
        }

        if isEnabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

enum LaunchAtLoginError: LocalizedError {
    case unsupported

    var errorDescription: String? {
        switch self {
        case .unsupported:
            "Launch at login is only available in the bundled app."
        }
    }
}

struct DebugLogActions {
    let writer: DebugLogWriter

    var logFilePath: String {
        writer.logFileURL.path
    }

    func append(_ message: String) {
        writer.append(message)
    }

    func setLoggingEnabled(_ isEnabled: Bool) {
        writer.setEnabled(isEnabled)
    }

    func openLog() {
        NSWorkspace.shared.open(writer.logFileURL)
    }

    func revealLogInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([writer.logFileURL])
    }

    func clearLog() {
        writer.clear()
        writer.append("Debug log cleared")
    }

    func copyLogPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logFilePath, forType: .string)
    }
}

@MainActor
final class SettingsSceneBridge {
    static let shared = SettingsSceneBridge()

    private var action: OpenSettingsAction?

    func register(_ action: OpenSettingsAction) {
        self.action = action
    }

    @discardableResult
    func open() -> Bool {
        guard let action else { return false }
        action()
        return true
    }
}

enum AboutPanelPresenter {
    @MainActor
    static func show() {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "Gestures",
            .credits: NSAttributedString(
                string: "Trackpad gesture shortcuts from your Mac menu bar."
            ),
        ]

        if let shortVersion, let buildVersion {
            options[.applicationVersion] = "\(shortVersion) (\(buildVersion))"
        } else if let shortVersion {
            options[.applicationVersion] = shortVersion
        }

        AppNavigation.activate()
        NSApp.orderFrontStandardAboutPanel(options: options)
    }
}
