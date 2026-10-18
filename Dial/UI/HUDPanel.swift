import AppKit
import Observation
import SwiftUI

/// Shows the HUD pill centred under the menu bar glyph, `space-3` below the
/// bar, and hides it 1.2s after the last update. Never more than one HUD: a
/// new mode replaces the old one in place.
@MainActor
final class HUDPanelController {
    /// Wide enough for the longest pill, with room for its shadow.
    private static let panelSize = CGSize(width: 520, height: 90)
    /// The HUD appears this long after a choose: the fold, then 120ms after the label.
    private static let afterChooseDelay = DialMotion.chooseFoldDelay + 0.12
    private static let orderOutDelay: TimeInterval = 0.3

    let presentation = HUDPresentation()
    var anchor: () -> DialAnchor? = { nil }

    private let model: DialModel
    private let panel = DialPanel()
    private var lastRevision: Int
    private var pendingShow: DispatchWorkItem?
    private var pendingHide: DispatchWorkItem?
    private var pendingOrderOut: DispatchWorkItem?

    init(model: DialModel) {
        self.model = model
        lastRevision = model.hudRevision

        let content = HUDView(presentation: presentation)
            .padding(.top, DialSpace.s3)
            .frame(width: Self.panelSize.width, height: Self.panelSize.height, alignment: .top)
        let hosting = NSHostingView(rootView: content)
        hosting.sizingOptions = []
        panel.contentView = hosting
        panel.setContentSize(Self.panelSize)
        panel.ignoresMouseEvents = true
        track()
    }

    private func track() {
        withObservationTracking {
            _ = model.hud
            _ = model.hudRevision
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.modelChanged()
                self?.track()
            }
        }
    }

    private func modelChanged() {
        guard let hud = model.hud else {
            hide()
            return
        }
        let isNewUpdate = model.hudRevision != lastRevision
        lastRevision = model.hudRevision
        guard isNewUpdate else {
            // A value read back later (brightness, desktops): update in place.
            if presentation.isShown { presentation.content = hud }
            return
        }
        pendingShow?.cancel()
        if hud.afterChoose {
            let work = DispatchWorkItem { [weak self] in self?.show(hud) }
            pendingShow = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.afterChooseDelay, execute: work)
        } else {
            show(hud)
        }
    }

    private func show(_ hud: HUDContent) {
        pendingHide?.cancel()
        pendingOrderOut?.cancel()
        presentation.content = hud
        presentation.revision += 1
        if !panel.isVisible {
            position()
            panel.orderFrontRegardless()
        }
        presentation.isShown = true

        let hide = DispatchWorkItem { [weak self] in self?.hide() }
        pendingHide = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + DialMotion.hudLinger, execute: hide)
    }

    private func hide() {
        pendingShow?.cancel()
        pendingHide?.cancel()
        presentation.isShown = false
        let orderOut = DispatchWorkItem { [weak self] in
            guard let self, !self.presentation.isShown else { return }
            self.panel.orderOut(nil)
        }
        pendingOrderOut = orderOut
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.orderOutDelay, execute: orderOut)
    }

    private func position() {
        guard let anchor = anchor() else { return }
        let size = Self.panelSize
        let screen = anchor.screen.frame
        let x = min(max(anchor.glyphCentreX - size.width / 2, screen.minX), screen.maxX - size.width)
        panel.setFrame(NSRect(x: x, y: anchor.menuBarBottom - size.height, width: size.width, height: size.height), display: false)
    }
}
