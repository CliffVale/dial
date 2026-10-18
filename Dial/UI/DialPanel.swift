import AppKit
import Observation
import SwiftUI

/// A borderless, non-activating panel at status-bar level that joins every
/// Space. It never becomes key or main, so the app being controlled keeps focus.
final class DialPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isMovable = false
        backgroundColor = .clear
        isOpaque = false
        // SwiftUI draws the dial's own shadows.
        hasShadow = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Lets the first click on a segment or the knob act, without activating Dial.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Where the dial hangs from: the menu bar glyph, in screen coordinates.
struct DialAnchor {
    var glyphCentreX: CGFloat
    var menuBarBottom: CGFloat
    var screen: NSScreen
}

/// Shows the dial under the status item while the model is picking.
@MainActor
final class DialPanelController {
    /// Room around the 260pt canvas for the ring's shadow (y 24, radius 24).
    private static let sideMargin: CGFloat = 48
    private static let bottomMargin: CGFloat = 64
    private static var panelSize: CGSize {
        CGSize(width: DialGeometry.canvas + sideMargin * 2, height: DialGeometry.canvas + bottomMargin)
    }
    /// The ring's top edge sits `space-4` below the menu bar; it is 18pt below
    /// the canvas top, so the canvas starts 2pt above the panel's top edge.
    private static var canvasTop: CGFloat {
        DialSpace.s4 - (DialGeometry.canvas / 2 - DialGeometry.ringOuterRadius)
    }
    /// Keeps the tether dot inside the gap when the panel slides from the edge.
    private static let maxTetherOffset: CGFloat = 30
    /// The dismiss animation is 180ms; the panel leaves the screen after it.
    private static let orderOutDelay: TimeInterval = 0.3

    let presentation = DialPresentation()
    /// Supplied by the status item.
    var anchor: () -> DialAnchor? = { nil }

    private let model: DialModel
    private let panel = DialPanel()
    private var lastPhase: DialModel.Phase
    private var lastPressCount: Int
    private var pendingHide: DispatchWorkItem?
    private var pendingOrderOut: DispatchWorkItem?

    init(model: DialModel) {
        self.model = model
        lastPhase = model.phase
        lastPressCount = model.pressCount

        let content = DialView(
            model: model,
            presentation: presentation,
            onSelect: { [weak model] mode in model?.select(mode) },
            onPress: { [weak model] in model?.handle(.press, from: "mouse") }
        )
        .frame(width: DialGeometry.canvas, height: DialGeometry.canvas)
        .offset(y: Self.canvasTop)
        .frame(width: Self.panelSize.width, height: Self.panelSize.height, alignment: .top)

        let hosting = FirstMouseHostingView(rootView: content)
        hosting.sizingOptions = []
        panel.contentView = hosting
        panel.setContentSize(Self.panelSize)
        panel.ignoresMouseEvents = true
        track()
    }

    // MARK: - Following the model

    private func track() {
        withObservationTracking {
            _ = model.phase
        } onChange: { [weak self] in
            // onChange runs before the change lands; act on the new value.
            Task { @MainActor in
                self?.phaseChanged()
                self?.track()
            }
        }
    }

    private func phaseChanged() {
        let phase = model.phase
        defer {
            lastPhase = phase
            lastPressCount = model.pressCount
        }
        guard phase != lastPhase else { return }

        if phase == .picking {
            show()
        } else if lastPhase == .picking {
            if model.pressCount != lastPressCount {
                // Chosen: let the press play, then fold up.
                schedule(hide, after: DialMotion.chooseFoldDelay)
            } else {
                hide()
            }
        }
    }

    // MARK: - Showing and hiding

    private func show() {
        pendingHide?.cancel()
        pendingOrderOut?.cancel()
        position()
        if !panel.isVisible {
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { presentation.isShown = false }
            panel.orderFrontRegardless()
        }
        panel.ignoresMouseEvents = false
        // Next run loop, so the hidden state renders before the summon animates.
        DispatchQueue.main.async { [weak self] in self?.presentation.isShown = true }
    }

    private func hide() {
        pendingHide?.cancel()
        presentation.isShown = false
        panel.ignoresMouseEvents = true
        let orderOut = DispatchWorkItem { [weak self] in
            guard let self, !self.presentation.isShown else { return }
            self.panel.orderOut(nil)
        }
        pendingOrderOut = orderOut
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.orderOutDelay, execute: orderOut)
    }

    private func schedule(_ action: @escaping () -> Void, after delay: TimeInterval) {
        pendingHide?.cancel()
        let work = DispatchWorkItem(block: action)
        pendingHide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Centres the dial under the glyph, sliding left or right to stay on
    /// screen while the tether dot stays under the glyph.
    private func position() {
        guard let anchor = anchor() else { return }
        let size = Self.panelSize
        let visible = anchor.screen.frame
        let idealX = anchor.glyphCentreX - size.width / 2
        let x = min(max(idealX, visible.minX), visible.maxX - size.width)
        let offset = anchor.glyphCentreX - (x + size.width / 2)
        presentation.tetherOffset = min(max(offset, -Self.maxTetherOffset), Self.maxTetherOffset)
        panel.setFrame(NSRect(x: x, y: anchor.menuBarBottom - size.height, width: size.width, height: size.height), display: false)
    }
}
