import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "hand.tap.fill", accessibilityDescription: "Gestures")
            button.image?.isTemplate = true
            button.toolTip = "Gestures"
        }

        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        addActionItem(
            title: "Settings...",
            keyEquivalent: ",",
            modifiers: [.command],
            action: #selector(openSettings)
        )
        menu.addItem(.separator())

        addStatusItem(
            title: model.isCaptureRunning ? "Capture Running" : "Capture Stopped",
            systemImageName: model.isCaptureRunning ? "wave.3.right.circle.fill" : "pause.circle"
        )
        addStatusItem(
            title: model.isAccessibilityTrusted ? "Accessibility Granted" : "Accessibility Required",
            systemImageName: model.isAccessibilityTrusted ? "checkmark.circle.fill" : "lock.shield"
        )
        addDisabledItem(title: model.captureMessage)

        menu.addItem(.separator())

        if !model.isAccessibilityTrusted {
            addActionItem(
                title: "Grant Accessibility Access",
                action: #selector(requestAccessibilityAccess)
            )
            addActionItem(
                title: "Open Accessibility Settings",
                action: #selector(openAccessibilitySettings)
            )
        }

        addActionItem(
            title: "Restart Capture",
            action: #selector(restartCapture)
        )

        menu.addItem(.separator())

        addActionItem(
            title: "About Gestures",
            action: #selector(showAboutPanel)
        )
        addActionItem(
            title: "Quit Gestures",
            keyEquivalent: "q",
            modifiers: [.command],
            action: #selector(quit)
        )
    }

    private func addDisabledItem(title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func addStatusItem(title: String, systemImageName: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.image = NSImage(systemSymbolName: systemImageName, accessibilityDescription: title)
        item.image?.isTemplate = true
        menu.addItem(item)
    }

    private func addActionItem(
        title: String,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = [],
        action: Selector
    ) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.keyEquivalentModifierMask = modifiers
        menu.addItem(item)
    }

    @objc
    private func openSettings() {
        AppNavigation.openSettings()
    }

    @objc
    private func requestAccessibilityAccess() {
        model.requestAccessibilityAccess()
    }

    @objc
    private func openAccessibilitySettings() {
        model.openAccessibilitySettings()
    }

    @objc
    private func restartCapture() {
        model.restartCapture()
    }

    @objc
    private func showAboutPanel() {
        model.showAboutPanel()
    }

    @objc
    private func quit() {
        AppNavigation.quit()
    }
}
