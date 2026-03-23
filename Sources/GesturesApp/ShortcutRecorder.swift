import AppKit
import GesturesCore
import SwiftUI

struct ShortcutRecorder: View {
    let shortcut: ShortcutBinding
    let onChange: (ShortcutBinding) -> Void
    var onDelete: (() -> Void)? = nil

    @State private var isRecording = false
    @State private var keyMonitor: Any?
    @State private var cancelMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(isRecording ? "Type Shortcut…" : shortcut.displayString) {
                isRecording ? stopRecording() : startRecording()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help(isRecording ? "Press a key combination, Escape to cancel, Delete to clear." : "Click to record a keyboard shortcut.")
            .accessibilityLabel("Keyboard Shortcut")
            .accessibilityValue(isRecording ? "Recording" : shortcut.displayString)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 2)
            }

            if isRecording {
                Text("Press a key chord. Esc cancels, ⌫ resets to default.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape
                stopRecording()
                return nil
            }

            if event.keyCode == 51 || event.keyCode == 117 { // Delete or Forward Delete
                onDelete?()
                stopRecording()
                return nil
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            onChange(ShortcutBinding(keyCode: event.keyCode, modifierFlags: modifiers))
            stopRecording()
            return nil
        }

        cancelMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            stopRecording()
            return event
        }
    }

    private func stopRecording() {
        isRecording = false

        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }

        if let cancelMonitor {
            NSEvent.removeMonitor(cancelMonitor)
            self.cancelMonitor = nil
        }
    }
}
