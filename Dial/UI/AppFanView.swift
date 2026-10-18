import AppKit
import SwiftUI

/// The app card fan for Apps mode (DESIGN.md, "App fan"; components/AppFan.md).
///
/// Drawn in a space whose origin is the dial's centre. Each card hangs off the
/// centre like the reference: turned to its arc angle, pushed out to r 160 and
/// centred on that ray, then scaled from its own top-left corner. The selected
/// card sits on the base angle, 4° below horizontal; neighbours step 12° away.
struct AppFanView: View {
    let apps: AppsMode
    let isOpen: Bool
    /// The Apps segment's centre angle, clockwise from 12 o'clock.
    let segmentAngle: Double
    /// Bumped on press: the selected card flashes.
    let pressCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let radius: CGFloat = 160
    static let baseAngle: Double = 4
    static let stepAngle: Double = 12
    static let cardSize = CGSize(width: 208, height: 44)
    private static let opacities: [Double] = [1, 0.62, 0.32, 0.12]
    private static let neighbourScale: CGFloat = 0.95

    var body: some View {
        ZStack(alignment: .topLeading) {
            connector
            ForEach(Array(apps.apps.enumerated()), id: \.element.processIdentifier) { index, app in
                card(app, index: index)
            }
        }
        .frame(width: 1, height: 1, alignment: .topLeading)
    }

    // MARK: - Cards

    /// Signed distance from the selection, the short way round the wrapping list.
    private func offset(of index: Int) -> Int {
        let count = apps.apps.count
        var offset = ((index - apps.selection) % count + count) % count
        if Double(offset) > Double(count) / 2 { offset -= count }
        return offset
    }

    private func card(_ app: NSRunningApplication, index: Int) -> some View {
        let offset = offset(of: index)
        let distance = abs(offset)
        let isSelected = distance == 0
        let visible = isOpen && distance < Self.opacities.count

        // Folded, cards gather along the Apps segment, small and clear.
        let angle = isOpen ? Self.baseAngle + Double(offset) * Self.stepAngle : segmentAngle - 90
        let reach: CGFloat = isOpen ? Self.radius : 120
        let scale: CGFloat = isOpen ? (isSelected ? 1 : Self.neighbourScale) : 0.6
        let animation: Animation? = reduceMotion ? nil : (isOpen
            ? DialMotion.fanCards.delay(Double(distance) * DialMotion.fanStagger)
            : DialMotion.dismiss)

        return AppCard(app: app, index: index, isSelected: isSelected, flashTrigger: isSelected ? pressCount : 0, reduceMotion: reduceMotion)
            .scaleEffect(scale, anchor: .topLeading)
            .offset(x: reach, y: -Self.cardSize.height / 2)
            .frame(width: 1, height: 1, alignment: .topLeading)
            .rotationEffect(.degrees(angle), anchor: .topLeading)
            .opacity(visible ? Self.opacities[distance] : 0)
            .zIndex(Double(10 - distance))
            .animation(animation, value: angle)
            .animation(animation, value: visible)
            .animation(animation, value: isSelected)
    }

    // MARK: - Connector

    /// A 1pt `cardBorderActive` line with an elbow, from the Apps segment's
    /// outer edge (r 118) to the selected card's leading edge, with a 2.5pt
    /// dot at the segment end.
    private var connector: some View {
        let t = segmentAngle * .pi / 180
        let r = DialGeometry.ringOuterRadius + DialGeometry.segmentLift
        let start = CGPoint(x: r * sin(t), y: -r * cos(t))
        let b = Self.baseAngle * .pi / 180
        let end = CGPoint(x: Self.radius * cos(b), y: Self.radius * sin(b))

        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: start)
                path.addLine(to: CGPoint(x: start.x + 14, y: start.y))
                path.addLine(to: CGPoint(x: end.x - 12, y: end.y))
                path.addLine(to: end)
            }
            .stroke(DialColor.cardBorderActive, lineWidth: 1)
            Circle()
                .fill(DialColor.cardBorderActive)
                .frame(width: 5, height: 5)
                .offset(x: start.x - 2.5, y: start.y - 2.5)
        }
        .opacity(isOpen ? 1 : 0)
        .animation(reduceMotion ? nil : (isOpen ? DialMotion.hud : DialMotion.dismiss), value: isOpen)
    }
}

/// One card: the app's icon, its name in `cardTitle` and its position in `cardMeta`.
private struct AppCard: View {
    let app: NSRunningApplication
    let index: Int
    let isSelected: Bool
    let flashTrigger: Int
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 10) {
            icon
            Text(app.localizedName ?? "App")
                .font(DialFont.cardTitle)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("⌘\(index + 1)")
                .font(DialFont.cardMeta)
                .foregroundStyle(DialColor.inkMuted)
        }
        .foregroundStyle(isSelected ? DialColor.ink : DialColor.inkMuted)
        // Inner padding from the reference (0 12 0 8).
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .frame(width: AppFanView.cardSize.width, height: AppFanView.cardSize.height)
        .background(
            RoundedRectangle(cornerRadius: DialRadius.md)
                .fill(isSelected ? DialColor.cardActive : DialColor.card)
        )
        .keyframeAnimator(initialValue: 0.0, trigger: reduceMotion ? 0 : flashTrigger) { content, flash in
            content.overlay(
                RoundedRectangle(cornerRadius: DialRadius.md)
                    .fill(DialColor.segmentActive)
                    .opacity(flash)
            )
        } keyframes: { _ in
            // The reference's 520ms flash, peaking at 30%.
            CubicKeyframe(1, duration: 0.156)
            CubicKeyframe(0, duration: 0.364)
        }
        .overlay(
            RoundedRectangle(cornerRadius: DialRadius.md)
                .strokeBorder(isSelected ? DialColor.cardBorderActive : DialColor.cardBorder, lineWidth: 1)
        )
        .compositingGroup()
        .dialShadow(.card)
    }

    /// The app's own icon at 26pt, where the reference uses a letter tile.
    private var icon: some View {
        Group {
            if let image = app.icon {
                Image(nsImage: image).resizable().interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: DialRadius.sm)
                    .fill(DialColor.ring)
                    .overlay(
                        Text(String((app.localizedName ?? "?").prefix(1)))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DialColor.iconActive)
                    )
            }
        }
        .frame(width: 26, height: 26)
    }
}
