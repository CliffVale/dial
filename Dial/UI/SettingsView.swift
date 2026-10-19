import AppKit
import SwiftUI

/// The Settings window: segment order, which modes are on, each mode's press
/// action, launch at login, and setup. Styled from the brand book: `canvas`
/// ground, `canvasRaised` panels, `title`, `body` and `caption` type.
struct SettingsView: View {
    @Bindable var store: SettingsStore
    var onShowSetupGuide: () -> Void = {}

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var preview = DialModel.preview(selecting: .volume)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DialSpace.s6) {
                header
                modes
                general
                setup
            }
            .padding(DialSpace.s6)
        }
        .frame(width: 560)
        .frame(minHeight: 640)
        .background(DialColor.canvas)
        .foregroundStyle(DialColor.ink)
        .onAppear { preview.apply(store.settings) }
        .onChange(of: store.settings) { preview.apply(store.settings) }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DialSpace.s4) {
            DialView(model: preview, presentation: Self.shownPresentation, showsTether: false)
                .scaleEffect(0.5)
                .frame(width: DialGeometry.canvas / 2, height: DialGeometry.canvas / 2)
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: DialSpace.s2) {
                Text("Dial")
                    .font(DialFont.title)
                    .tracking(-0.22)
                Text("Double press the Smart Dial to open the wheel. Turn to pick a mode, press to choose it. The ring follows the order below.")
                    .font(DialFont.body)
                    .foregroundStyle(DialColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private static let shownPresentation: DialPresentation = {
        let presentation = DialPresentation()
        presentation.isShown = true
        return presentation
    }()

    // MARK: - Modes

    private var modes: some View {
        VStack(alignment: .leading, spacing: DialSpace.s2) {
            SectionCaption(text: "Modes")
            RaisedPanel {
                List {
                    ForEach(store.settings.order, id: \.self) { mode in
                        ModeRow(
                            mode: mode,
                            isEnabled: !store.settings.disabled.contains(mode),
                            canDisable: store.settings.enabledModes.count > 1,
                            pressAction: store.settings.pressAction(for: mode),
                            setEnabled: { store.settings.setEnabled($0, for: mode) },
                            setPressAction: { store.settings.setPressAction($0, for: mode) }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(DialColor.hairline)
                    }
                    .onMove { store.settings.move(fromOffsets: $0, toOffset: $1) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(height: CGFloat(store.settings.order.count) * 44)
            }
            Text("Drag to reorder the ring, clockwise from the gap. Modes you turn off stay on the ring, dimmed, and turning skips them.")
                .font(DialFont.caption)
                .foregroundStyle(DialColor.inkMuted)
        }
    }

    // MARK: - General

    private var general: some View {
        VStack(alignment: .leading, spacing: DialSpace.s2) {
            SectionCaption(text: "General")
            RaisedPanel {
                row {
                    Text("Open Dial when you log in")
                    Spacer()
                    Toggle("", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: launchAtLogin) { LaunchAtLogin.set(launchAtLogin) }
                }
                if LaunchAtLogin.needsApproval {
                    Divider().overlay(DialColor.hairline)
                    row {
                        Text("macOS needs you to allow Dial in Login Items.")
                            .foregroundStyle(DialColor.inkMuted)
                        Spacer()
                        Button("Open Login Items") { LaunchAtLogin.openLoginItemsSettings() }
                            .buttonStyle(DialChipButtonStyle())
                    }
                }
                Divider().overlay(DialColor.hairline)
                row {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Testing tools")
                        Text("⌃⌥ ← → turn, ⌃⌥Space presses, ⌃⌥D double presses, plus the debug log")
                            .font(DialFont.caption)
                            .foregroundStyle(DialColor.inkMuted)
                    }
                    Spacer()
                    Toggle("", isOn: $store.testingTools)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                Divider().overlay(DialColor.hairline)
                row {
                    Text("Reduce motion")
                    Spacer()
                    Text(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? "On, from System Settings" : "Follows System Settings")
                        .foregroundStyle(DialColor.inkMuted)
                }
            }
        }
    }

    // MARK: - Setup

    private var setup: some View {
        VStack(alignment: .leading, spacing: DialSpace.s2) {
            SectionCaption(text: "Setup")
            RaisedPanel {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    row {
                        StatusMark(done: Permissions.isAccessibilityTrusted)
                        Text("Accessibility")
                        Spacer()
                        Text(Permissions.isAccessibilityTrusted ? "On" : "Needed for every mode")
                            .foregroundStyle(DialColor.inkMuted)
                        if !Permissions.isAccessibilityTrusted {
                            Button("Open Settings") { Permissions.openAccessibilitySettings() }
                                .buttonStyle(DialChipButtonStyle())
                        }
                    }
                }
                Divider().overlay(DialColor.hairline)
                row {
                    Text("Nothing X gestures, buds and permissions")
                    Spacer()
                    Button("Setup Guide") { onShowSetupGuide() }
                        .buttonStyle(DialChipButtonStyle())
                }
            }
        }
    }

    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: DialSpace.s3) { content() }
            .font(DialFont.body)
            .padding(.horizontal, DialSpace.s4)
            .frame(minHeight: 44)
    }
}

/// One mode: drag handle, icon, name, press action and on/off.
private struct ModeRow: View {
    let mode: ModeID
    let isEnabled: Bool
    let canDisable: Bool
    let pressAction: PressAction
    let setEnabled: (Bool) -> Void
    let setPressAction: (PressAction) -> Void

    var body: some View {
        HStack(spacing: DialSpace.s3) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(DialColor.inkMuted)
            DialIconView(icon: DialIcon(mode), size: 16)
                .foregroundStyle(isEnabled ? DialColor.ink : DialColor.inkMuted)
            Text(mode.label)
                .font(DialFont.body)
                .foregroundStyle(isEnabled ? DialColor.ink : DialColor.inkMuted)
            Spacer()
            if mode.pressOptions.count > 1 {
                Picker("Press", selection: Binding(get: { pressAction }, set: setPressAction)) {
                    ForEach(mode.pressOptions, id: \.self) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                .disabled(!isEnabled)
            } else {
                Text(pressAction.label)
                    .font(DialFont.body)
                    .foregroundStyle(DialColor.inkMuted)
            }
            Toggle("", isOn: Binding(get: { isEnabled }, set: setEnabled))
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(isEnabled && !canDisable)
                .help(isEnabled && !canDisable ? "At least one mode stays on." : "")
        }
        .frame(height: 36)
    }
}

/// The Settings window, opened from the menu bar item's menu.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let store: SettingsStore
    var onShowSetupGuide: () -> Void = {}

    init(store: SettingsStore) {
        self.store = store
    }

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 720),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Dial Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(store: store, onShowSetupGuide: { [weak self] in self?.onShowSetupGuide() }))
            window.center()
            window.setFrameAutosaveName("DialSettings")
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
