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
            // A value read back later (brightness, desktops, Mission Control): update in place.
            guard presentation.isShown else { return }
            let wasSticky = presentation.content?.sticky ?? false
            presentation.content = hud
            if hud.sticky != wasSticky {
                position(sticky: hud.sticky)
                scheduleLinger(for: hud)
            }
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
        let moved = presentation.content?.sticky != hud.sticky
        presentation.content = hud
        presentation.revision += 1
        if !panel.isVisible || moved {
            position(sticky: hud.sticky)
            panel.orderFrontRegardless()
        }
        presentation.isShown = true
        scheduleLinger(for: hud)
    }

    /// Hides 1.2s after the last update, unless the HUD is sticky.
    private func scheduleLinger(for hud: HUDContent) {
        pendingHide?.cancel()
        guard !hud.sticky else { return }
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

    /// Under the menu bar glyph; or, while sticky (Mission Control), at the
    /// bottom centre of the screen, `space-4` above the Dock.
    private func position(sticky: Bool) {
        guard let anchor = anchor() else { return }
        let size = Self.panelSize
        let screen = anchor.screen.frame
        // Mission Control draws above status-bar level; the sticky HUD has to sit higher.
        panel.level = sticky ? .screenSaver : .statusBar
        if sticky {
            // The pill sits `space-3` below the panel's top edge and is 34pt tall.
            let pillBottom = (MissionControlUI.dockTop ?? anchor.screen.visibleFrame.minY) + DialSpace.s4
            let top = pillBottom + 34 + DialSpace.s3
            panel.setFrame(NSRect(x: screen.midX - size.width / 2, y: top - size.height, width: size.width, height: size.height), display: false)
            return
        }
        let x = min(max(anchor.glyphCentreX - size.width / 2, screen.minX), screen.maxX - size.width)
        panel.setFrame(NSRect(x: x, y: anchor.menuBarBottom - size.height, width: size.width, height: size.height), display: false)
    }
}
