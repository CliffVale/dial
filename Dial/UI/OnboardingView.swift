import AppKit
import SwiftUI

/// First-run setup: the Nothing X gestures, the buds as the output,
/// Accessibility, a first try, and launch at login. Each step checks itself
/// live, so it's clear what's left.
struct OnboardingView: View {
    let model: DialModel
    /// Whether the buds are the sound output right now.
    let budsConnected: () -> Bool
    let onDone: () -> Void

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    /// Counts at the moment the guide opened, so only new gestures count.
    @State private var startCounts: BudsEventCounts?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(alignment: .leading, spacing: DialSpace.s6) {
                VStack(alignment: .leading, spacing: DialSpace.s2) {
                    Text("Set up Dial")
                        .font(DialFont.title)
                        .tracking(-0.22)
                    Text("Dial listens to your CMF Buds Pro 2 case. Each step ticks itself off as it's done.")
                        .font(DialFont.body)
                        .foregroundStyle(DialColor.inkMuted)
                }
                VStack(spacing: DialSpace.s3) {
                    step(1, "Set the Smart Dial gestures in Nothing X", done: gesturesSeen,
                         detail: "In the Nothing X app, open your buds' Smart Dial settings and set: press → Play/Pause, double press → Next track, rotate → Volume.")
                    step(2, "Make the buds your sound output", done: budsConnected(),
                         detail: "Connect the buds and choose them in Control Centre → Sound. Keep the case lid closed: the dial only sends with the lid shut.")
                    step(3, "Allow Accessibility", done: Permissions.isAccessibilityTrusted,
                         detail: "Dial presses keys, scrolls and brings windows forward for you. Turn on Dial in Privacy & Security → Accessibility.") {
                        if !Permissions.isAccessibilityTrusted {
                            Button("Open Settings") {
                                Permissions.requestAccessibility(reason: "finish setup")
                                Permissions.openAccessibilitySettings()
                            }
                            .buttonStyle(DialChipButtonStyle())
                        }
                    }
                    step(4, "Try it", done: triedIt,
                         detail: "Double press the dial: the wheel drops from the menu bar. Turn to pick a mode and press to choose it.")
                    step(5, "Open Dial when you log in", done: launchAtLogin, detail: "So the dial is ready whenever your buds are.") {
                        Toggle("", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: launchAtLogin) { LaunchAtLogin.set(launchAtLogin) }
                    }
                }
                HStack {
                    Text("You can open this guide again from the menu bar item.")
                        .font(DialFont.caption)
                        .foregroundStyle(DialColor.inkMuted)
                    Spacer()
                    Button("Done") { onDone() }
                        .buttonStyle(DialChipButtonStyle(prominent: true))
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(DialSpace.s6)
        }
        .frame(width: 560)
        .background(DialColor.canvas)
        .foregroundStyle(DialColor.ink)
        .onAppear { startCounts = model.budsEvents }
    }

    /// A press or double press has arrived from the buds: the gestures are set.
    private var gesturesSeen: Bool {
        model.budsEvents.presses + model.budsEvents.doublePresses > 0
    }

    /// The wheel opened from the buds and a mode was chosen.
    private var triedIt: Bool {
        guard let start = startCounts else { return false }
        return model.budsEvents.doublePresses > start.doublePresses && model.activeMode != nil
    }

    private func step(_ number: Int, _ title: String, done: Bool, detail: String) -> some View {
        step(number, title, done: done, detail: detail) { EmptyView() }
    }

    private func step<Accessory: View>(_ number: Int, _ title: String, done: Bool, detail: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        RaisedPanel {
            HStack(alignment: .top, spacing: DialSpace.s3) {
                StatusMark(done: done)
                VStack(alignment: .leading, spacing: DialSpace.s1) {
                    Text("\(number). \(title)")
                        .font(DialFont.body.weight(.semibold))
                    Text(detail)
                        .font(DialFont.body)
                        .foregroundStyle(DialColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DialSpace.s2)
                accessory()
            }
            .padding(DialSpace.s4)
        }
    }
}

/// The setup guide window: on first launch, and from the menu.
@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?
    private let model: DialModel
    private let store: SettingsStore
    private let budsConnected: () -> Bool

    init(model: DialModel, store: SettingsStore, budsConnected: @escaping () -> Bool) {
        self.model = model
        self.store = store
        self.budsConnected = budsConnected
    }

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Set up Dial"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: OnboardingView(
                model: model,
                budsConnected: budsConnected,
                onDone: { [weak self] in self?.finish() }
            ))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        store.hasCompletedOnboarding = true
        window?.close()
    }
}
