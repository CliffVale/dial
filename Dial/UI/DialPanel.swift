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
    /// Room left of the 260pt canvas for the ring's shadow (y 24, radius 24).
    private static let sideMargin: CGFloat = 48
    /// The dial's centre, from the panel's left edge.
    private static let dialCentreX = sideMargin + DialGeometry.canvas / 2
    /// To the right the panel reaches past the app fan: r 160 plus a 208pt
    /// card plus its shadow. Downward it clears the lowest card (40°).
    private static let fanReach = AppFanView.radius + AppFanView.cardSize.width + 24
    private static var panelSize: CGSize {
        CGSize(width: dialCentreX + fanReach, height: 400)
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
    private let apps: AppsMode?
    private var wasVisible = false
    private var lastPressCount: Int
    private var pendingHide: DispatchWorkItem?
    private var pendingOrderOut: DispatchWorkItem?

    init(model: DialModel, apps: AppsMode?) {
        self.model = model
        self.apps = apps
        lastPressCount = model.pressCount

        let content = DialPanelContent(
            model: model,
            presentation: presentation,
            apps: apps,
            dialCentre: CGPoint(x: Self.dialCentreX, y: Self.canvasTop + DialGeometry.canvas / 2)
        )
        .frame(width: Self.panelSize.width, height: Self.panelSize.height, alignment: .topLeading)

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
            _ = model.isFanOpen
        } onChange: { [weak self] in
            // onChange runs before the change lands; act on the new value.
            Task { @MainActor in
                self?.visibilityChanged()
                self?.track()
            }
        }
    }

    /// The dial is out while picking, and while the app fan is open.
    private func visibilityChanged() {
        let visible = model.phase == .picking || model.isFanOpen
        defer {
            wasVisible = visible
            lastPressCount = model.pressCount
        }
        if visible && !wasVisible {
            show()
        } else if visible {
            // Picking to the fan, or back: already out.
            pendingHide?.cancel()
        } else if wasVisible {
            if model.pressCount != lastPressCount {
                // Chosen or opened: let the press play, then fold up.
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

    /// Centres the dial under the glyph, sliding it left or right to keep the
    /// dial on screen while the tether dot stays under the glyph. The fan may
    /// run off the right edge; the dial never does.
    private func position() {
        guard let anchor = anchor() else { return }
        let size = Self.panelSize
        let screen = anchor.screen.frame
        let halfDial = DialGeometry.canvas / 2 + Self.sideMargin
        let centre = min(max(anchor.glyphCentreX, screen.minX + halfDial), screen.maxX - halfDial)
        let offset = anchor.glyphCentreX - centre
        presentation.tetherOffset = min(max(offset, -Self.maxTetherOffset), Self.maxTetherOffset)
        let x = centre - Self.dialCentreX
        panel.setFrame(NSRect(x: x, y: anchor.menuBarBottom - size.height, width: size.width, height: size.height), display: false)
    }
}

/// The dial, and the app fan to its right, laid out in the panel.
private struct DialPanelContent: View {
    let model: DialModel
    let presentation: DialPresentation
    let apps: AppsMode?
    let dialCentre: CGPoint

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let apps {
                AppFanView(
                    apps: apps,
                    isOpen: model.isFanOpen && presentation.isShown,
                    segmentAngle: DialGeometry.centreAngle(model.segmentIndex(of: .apps)),
                    pressCount: model.pressCount
                )
                .offset(x: dialCentre.x, y: dialCentre.y)
            }
            DialView(
                model: model,
                presentation: presentation,
                onSelect: { [weak model] mode in model?.select(mode) },
                onPress: { [weak model] in model?.handle(.press, from: "mouse") }
            )
            .frame(width: DialGeometry.canvas, height: DialGeometry.canvas)
            .offset(x: dialCentre.x - DialGeometry.canvas / 2, y: dialCentre.y - DialGeometry.canvas / 2)
        }
    }
}
