import SwiftUI

/// Geometry on the dial's 260 × 260 canvas, angles clockwise from 12 o'clock.
enum DialPath {
    static let centre = CGPoint(x: DialGeometry.canvas / 2, y: DialGeometry.canvas / 2)

    static func point(radius: CGFloat, angle: Double) -> CGPoint {
        let t = angle * .pi / 180
        return CGPoint(x: centre.x + radius * sin(t), y: centre.y - radius * cos(t))
    }

    /// An annular sector, its arcs sampled every half degree.
    static func sector(inner: CGFloat, outer: CGFloat, from a0: Double, to a1: Double) -> Path {
        var path = Path()
        let samples = max(2, Int((a1 - a0) * 2))
        for i in 0...samples {
            let p = point(radius: outer, angle: a0 + (a1 - a0) * Double(i) / Double(samples))
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        for i in (0...samples).reversed() {
            path.addLine(to: point(radius: inner, angle: a0 + (a1 - a0) * Double(i) / Double(samples)))
        }
        path.closeSubpath()
        return path
    }

    /// A sector with rounded corners: inset by `corner`, then grown back by a
    /// round-joined stroke twice as wide (DESIGN.md, "Ring").
    static func roundedSector(inner: CGFloat, outer: CGFloat, from a0: Double, to a1: Double, corner: CGFloat) -> Path {
        let pull = asin(corner / ((inner + outer) / 2)) * 180 / .pi
        let core = sector(inner: inner + corner, outer: outer - corner, from: a0 + pull, to: a1 - pull)
        let grown = core.strokedPath(StrokeStyle(lineWidth: corner * 2, lineJoin: .round))
        return core.union(grown)
    }
}

/// The C-shaped ring body, open at 12 o'clock, with 10pt rounded ends.
struct RingShape: Shape {
    func path(in rect: CGRect) -> Path {
        let half = DialGeometry.ringGapDegrees / 2
        return DialPath.roundedSector(
            inner: DialGeometry.ringInnerRadius,
            outer: DialGeometry.ringOuterRadius,
            from: half,
            to: 360 - half,
            corner: DialGeometry.ringEndCornerRadius
        )
    }
}

/// The lifted, selected segment, drawn at segment 0 and rotated into place.
/// Matches the reference: from r 67 to r 118, 0.6° in from each boundary.
struct ActiveSegmentShape: Shape {
    func path(in rect: CGRect) -> Path {
        let a0 = DialGeometry.ringGapDegrees / 2
        return DialPath.roundedSector(
            inner: DialGeometry.ringInnerRadius - 1,
            outer: DialGeometry.ringOuterRadius + DialGeometry.segmentLift,
            from: a0 + 0.6,
            to: a0 + DialGeometry.segmentDegrees - 0.6,
            corner: DialGeometry.segmentCornerRadius
        )
    }
}

/// 1pt dividers on the segment boundaries, from r 75 to r 105.
struct RingDividers: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for k in 1..<DialGeometry.segmentCount {
            let angle = DialGeometry.ringGapDegrees / 2 + DialGeometry.segmentDegrees * Double(k)
            path.move(to: DialPath.point(radius: DialGeometry.ringInnerRadius + 7, angle: angle))
            path.addLine(to: DialPath.point(radius: DialGeometry.ringOuterRadius - 7, angle: angle))
        }
        return path
    }
}

/// 45° stripes, 1.6pt wide on a 5pt pitch, filling the canvas.
struct HatchShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let pitch: CGFloat = 5
        let width: CGFloat = 1.6
        // Generous bounds, so the stripes still cover the canvas once rotated.
        let span = (rect.width + rect.height) * 2
        var x = -span
        while x < span {
            path.addRect(CGRect(x: x, y: -span, width: width, height: span * 2))
            x += pitch
        }
        return path.applying(CGAffineTransform(rotationAngle: .pi / 4))
    }
}

/// The ring with its dividers and the selected segment. The highlight turns
/// with the model's accumulated angle; it never snaps across 0°.
struct RingView: View {
    /// Accumulated highlight angle, clockwise from 12 o'clock.
    let highlightAngle: Double
    /// Bumped on each press: the selected segment flashes from `iconIdle`.
    let pressCount: Int
    let detentAnimation: Animation?
    let reduceMotion: Bool

    /// 1 at the start of a press flash, fading to 0.
    @State private var flash: Double = 0

    private var segmentRotation: Double {
        highlightAngle - DialGeometry.centreAngle(0)
    }

    var body: some View {
        ZStack {
            Group {
                RingShape().fill(DialColor.ring)
                RingDividers().stroke(DialColor.ringDivider, lineWidth: 1)
                activeSegment
                    .rotationEffect(.degrees(segmentRotation))
                    .animation(detentAnimation, value: highlightAngle)
            }
            .compositingGroup()
            .dialShadow(.ring)
        }
        .frame(width: DialGeometry.canvas, height: DialGeometry.canvas)
    }

    private var activeSegment: some View {
        ZStack {
            ActiveSegmentShape().fill(DialColor.segmentActive)
            ActiveSegmentShape().fill(DialColor.iconIdle).opacity(flash)
            HatchShape()
                .fill(DialColor.segmentHatch)
                .opacity(0.6)
                .clipShape(ActiveSegmentShape())
        }
        .onChange(of: pressCount) {
            guard !reduceMotion else { return }
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { flash = 1 }
            DispatchQueue.main.async {
                // The 360ms flash from motion.md; no token covers it.
                withAnimation(.easeOut(duration: 0.36)) { flash = 0 }
            }
        }
    }
}

extension View {
    /// Applies a `DialShadow` token, picking its opacity for the appearance.
    func dialShadow(_ shadow: DialShadow) -> some View {
        modifier(DialShadowModifier(shadow: shadow))
    }
}

private struct DialShadowModifier: ViewModifier {
    let shadow: DialShadow
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.shadow(
            color: .black.opacity(colorScheme == .dark ? shadow.darkOpacity : shadow.lightOpacity),
            radius: shadow.radius,
            y: shadow.y
        )
    }
}
