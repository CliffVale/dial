import AppKit
import SwiftUI

/// The debug log window: live state on top, every log line below.
struct DebugLogView: View {
    let model: DialModel
    let encoder: VolumeEncoder
    let log: DebugLog

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            stateHeader
                .padding(12)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(log.entries) { entry in
                            Text(entry.text)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: log.entries.last?.id) { _, last in
                    if let last { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
            Divider()
            HStack {
                Button("Clear") { log.clear() }
                Button("Copy All") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(log.allText, forType: .string)
                }
                Spacer()
                Button("Show Log File") {
                    NSWorkspace.shared.activateFileViewerSelecting([log.fileURL])
                }
            }
            .padding(10)
        }
        .frame(minWidth: 620, minHeight: 420)
    }

    private var stateHeader: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
            row("State", model.phaseDescription)
            row("Selection", "\(model.selectedMode.label)  ·  step \(model.selectionStep)  ·  \(Int(model.selectionAngle))°")
            row("Last detent gap", model.lastDetentInterval.map { String(format: "%.0f ms%@", $0 * 1000, model.isFastSpin ? "  (fast spin)" : "") } ?? "–")
            row("Volume", model.shouldPark ? "parked" : "pass-through")
        }
        .font(.system(size: 12))
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
        }
    }
}

final class DebugLogWindowController {
    private var window: NSWindow?
    private let model: DialModel
    private let encoder: VolumeEncoder

    init(model: DialModel, encoder: VolumeEncoder) {
        self.model = model
        self.encoder = encoder
    }

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Dial Debug Log"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: DebugLogView(model: model, encoder: encoder, log: .shared))
            window.center()
            window.setFrameAutosaveName("DialDebugLog")
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
