import AppKit
import SwiftUI

/// The white, knurled knob in the middle of the dial (DESIGN.md, "Knob").
///
/// Layers, outermost first, as in the reference:
/// - arrival: turns in from −90° at 80% scale on summon
/// - press: sinks to 92% with a tighter shadow, sends out the glow ring
/// - face: knurl, teeth, gradient, rim and pointer marks, turning to `angle`
/// - rim light and label, which never turn
struct KnobView: View {
    /// Where the 0° pointer mark points, clockwise from 12 o'clock. Accumulated.
    let angle: Double
    let mode: ModeID
    let pressCount: Int
    let isShown: Bool
    let turnAnimation: Animation?
    let reduceMotion: Bool
    var showsLabel = true

    @State private var isPressed = false
    @State private var glowScale: CGFloat = 1
    @State private var glowOpacity: Double = 0

    var body: some View {
        ZStack {
            glowRing
            KnobFace()
                .rotationEffect(.degrees(angle))
                .animation(turnAnimation, value: angle)
            rimLight
            if showsLabel {
                KnobLabel(mode: mode, reduceMotion: reduceMotion)
            }
        }
        .frame(width: DialGeometry.canvas, height: DialGeometry.canvas)
        .scaleEffect(isPressed ? DialMotion.pressScale : 1)
        // One shadow for the knob's silhouette, not one per layer.
        .compositingGroup()
        .dialShadow(isPressed ? .knobPressed : .knob)
        .rotationEffect(.degrees(isShown || reduceMotion ? 0 : -90))
        .scaleEffect(isShown || reduceMotion ? 1 : 0.8)
        .animation(reduceMotion ? nil : (isShown ? DialMotion.summonKnob : DialMotion.dismiss), value: isShown)
        .onChange(of: pressCount) { press() }
    }

    private func press() {
        guard !reduceMotion else { return }
        withAnimation(DialMotion.pressDown) { isPressed = true }
        // Held for 110ms like the reference, then springs back.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
            withAnimation(DialMotion.pressUp) { isPressed = false }
        }
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            glowScale = 1
            glowOpacity = 0.9
        }
        DispatchQueue.main.async {
            withAnimation(DialMotion.glowPulse) {
                glowScale = 1.24
                glowOpacity = 0
            }
        }
    }

    /// 3pt `glow` circle at the knob's edge: scales 1 → 1.24, fades 0.9 → 0.
    private var glowRing: some View {
        Circle()
            .stroke(DialColor.glow, lineWidth: 3)
            .frame(width: DialGeometry.knobRadius * 2, height: DialGeometry.knobRadius * 2)
            .scaleEffect(glowScale)
            .opacity(glowOpacity)
    }

    /// 2pt `glow` arc at 55% on r 43.5, from 280° to 345°. It doesn't turn.
    private var rimLight: some View {
        Path { path in
            let r = DialGeometry.knobRadius - 5.5
            for degree in stride(from: 280.0, through: 345.0, by: 0.5) {
                let p = DialPath.point(radius: r, angle: degree)
                degree == 280 ? path.move(to: p) : path.addLine(to: p)
            }
        }
        .stroke(DialColor.glow, lineWidth: 2)
        .opacity(0.55)
    }
}

/// The turning part of the knob, drawn on the 260 canvas.
private struct KnobFace: View {
    var body: some View {
        Canvas { context, _ in
            let c = DialPath.centre
            let knob = DialGeometry.knobRadius

            func circle(_ r: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            }

            // Knurled band with 90 teeth, one every 4°.
            context.fill(circle(knob), with: .color(DialColor.knobKnurl))
            var teeth = Path()
            for t in 0..<DialGeometry.knurlTeeth {
                let a = Double(t) * 360 / Double(DialGeometry.knurlTeeth)
                teeth.move(to: DialPath.point(radius: knob - 3.6, angle: a))
                teeth.addLine(to: DialPath.point(radius: knob - 0.6, angle: a))
            }
            context.stroke(teeth, with: .color(DialColor.knobFace), lineWidth: 1.1)

            // Face: radial gradient centred at 38%, 32% of its bounds.
            let face = knob - DialGeometry.knurlBand - 1
            let bounds = CGRect(x: c.x - face, y: c.y - face, width: face * 2, height: face * 2)
            let highlight = CGPoint(x: bounds.minX + bounds.width * 0.38, y: bounds.minY + bounds.height * 0.32)
            context.fill(circle(face), with: .radialGradient(
                Gradient(colors: [DialColor.knobFace, DialColor.knobShade]),
                center: highlight,
                startRadius: 0,
                endRadius: bounds.width * 0.78
            ))

            // Inner rim.
            context.stroke(circle(knob - 11), with: .color(DialColor.knobShade), lineWidth: 1)

            // The two engraved pointer marks, at 0° and 180°.
            var marks = Path()
            for a in [0.0, 180.0] {
                marks.move(to: DialPath.point(radius: knob - 15, angle: a))
                marks.addLine(to: DialPath.point(radius: knob - 8, angle: a))
            }
            context.stroke(marks, with: .color(DialColor.knobInk), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .frame(width: DialGeometry.canvas, height: DialGeometry.canvas)
    }
}

/// The mode's icon and short name, upright. A new label rises 4pt and fades in.
private struct KnobLabel: View {
    let mode: ModeID
    let reduceMotion: Bool

    /// The reference sets the name's baseline at y 141; this is the centre of
    /// its line box for that baseline.
    private static let nameCentreY: CGFloat = {
        let font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        return 141 - font.ascender + (font.ascender - font.descender) / 2
    }()

    var body: some View {
        ZStack {
            content
                .id(mode)
                .transition(reduceMotion ? .identity : .asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 4)).combined(with: .scale(scale: 0.96)),
                    removal: .identity
                ))
        }
        .animation(reduceMotion ? nil : DialMotion.labelSwap, value: mode)
        .frame(width: DialGeometry.canvas, height: DialGeometry.canvas)
    }

    private var content: some View {
        ZStack {
            DialIconView(icon: DialIcon(mode), size: DialGeometry.iconSize, strokeWidth: 1.6)
                .position(x: DialPath.centre.x, y: 116)
            Text(mode.shortLabel)
                .font(DialFont.knobLabel)
                .tracking(0.2)
                .fixedSize()
                .position(x: DialPath.centre.x, y: Self.nameCentreY)
        }
        .foregroundStyle(DialColor.knobInk)
        .frame(width: DialGeometry.canvas, height: DialGeometry.canvas)
    }
}
