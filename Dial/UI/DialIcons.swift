import AppKit
import SwiftUI

/// The line icons from design/reference, drawn on a 24 × 24 grid with round
/// caps and joins. They stand in for the SF Symbols DESIGN.md suggests, so the
/// dial matches the reference screenshots.
enum DialIcon: String {
    case volume, brightness, apps, mission, desktops, tabs, scroll, undo, slides
    /// The menu bar glyph: a ring open at the top around a small circle.
    case ring

    init(_ mode: ModeID) {
        switch mode {
        case .volume: self = .volume
        case .brightness: self = .brightness
        case .apps: self = .apps
        case .missionControl: self = .mission
        case .desktops: self = .desktops
        case .tabs: self = .tabs
        case .scroll: self = .scroll
        case .undoRedo: self = .undo
        case .slides: self = .slides
        }
    }

    private enum Element {
        case path(String)
        case circle(CGFloat, CGFloat, CGFloat)
        case rect(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
    }

    private var elements: [Element] {
        switch self {
        case .volume:
            return [.path("M11 5 6.5 9H3.5v6h3l4.5 4z"), .path("M15.5 9a4.5 4.5 0 0 1 0 6"), .path("M18.5 6a8.5 8.5 0 0 1 0 12")]
        case .brightness:
            return [.circle(12, 12, 3.75), .path("M12 2.5v2M12 19.5v2M4.6 4.6 6 6M18 18l1.4 1.4M2.5 12h2M19.5 12h2M4.6 19.4 6 18M18 6l1.4-1.4")]
        case .apps:
            return [6, 12, 18].flatMap { y in [6, 12, 18].map { x in Element.circle(x, y, 1.6) } }
        case .mission:
            return [.rect(2.5, 10, 8.5, 7.5, 1.5), .rect(13, 10, 8.5, 7.5, 1.5), .path("M9 6l3-3 3 3"), .path("M5 21h14")]
        case .desktops:
            return [.rect(2.5, 4, 14, 10, 1.5), .path("M7.5 18h11a2 2 0 0 0 2-2V8.5")]
        case .tabs:
            return [.rect(3, 5, 18, 15, 2), .path("M3 9.5h18"), .path("M9.5 5v4.5")]
        case .scroll:
            return [.rect(7, 3, 10, 18, 5), .path("M12 7v3")]
        case .undo:
            return [.path("M9 14 4 9l5-5"), .path("M4 9h10.5a5.5 5.5 0 0 1 0 11H11")]
        case .slides:
            return [.rect(3, 4, 18, 12, 1.5), .path("M12 16v4M8 20h8"), .path("m10.5 8 4 2-4 2z")]
        case .ring:
            return [.path("M8.6 3.3A9 9 0 1 0 15.4 3.3"), .circle(12, 12, 3.2)]
        }
    }

    /// The icon's outline on the 24 × 24 grid.
    var path: Path {
        var path = Path()
        for element in elements {
            switch element {
            case .path(let d): SVGPath.append(d, to: &path)
            case .circle(let x, let y, let r): path.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            case .rect(let x, let y, let w, let h, let r): path.addRoundedRect(in: CGRect(x: x, y: y, width: w, height: h), cornerSize: CGSize(width: r, height: r))
            }
        }
        return path
    }

    /// A template image for the menu bar, stroked like the reference.
    func templateImage(size: CGFloat, strokeWidth: CGFloat = 1.5) -> NSImage {
        let cgPath = path.cgPath
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.scaleBy(x: size / 24, y: size / 24)
            context.addPath(cgPath)
            context.setLineWidth(strokeWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setStrokeColor(NSColor.black.cgColor)
            context.strokePath()
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// Draws a `DialIcon` at any size. The stroke is in grid units (1.5 of 24),
/// as in the reference, so an 18pt icon has a stroke of about 1.1pt.
struct DialIconView: View {
    let icon: DialIcon
    var size: CGFloat = DialGeometry.iconSize
    var strokeWidth: CGFloat = 1.5

    var body: some View {
        icon.path
            .stroke(style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
            .frame(width: 24, height: 24)
            .scaleEffect(size / 24)
            .frame(width: size, height: size)
    }
}

/// Just enough SVG path syntax for the reference icons: M L H V A Z, absolute
/// and relative, with implicit repeats.
private enum SVGPath {
    static func append(_ d: String, to path: inout Path) {
        var tokens = tokenize(d)[...]
        var current = CGPoint.zero
        var start = CGPoint.zero
        var command: Character = "M"

        func number() -> CGFloat {
            guard case .number(let n)? = tokens.popFirst() else { return 0 }
            return n
        }
        func hasNumber() -> Bool {
            if case .number? = tokens.first { return true }
            return false
        }

        while !tokens.isEmpty {
            if case .command(let c)? = tokens.first {
                command = c
                tokens.removeFirst()
            }
            let relative = command.isLowercase
            let base = relative ? current : .zero
            switch command.uppercased() {
            case "M":
                current = CGPoint(x: base.x + number(), y: base.y + number())
                start = current
                path.move(to: current)
                // Further pairs after a move are lines.
                command = relative ? "l" : "L"
            case "L":
                current = CGPoint(x: base.x + number(), y: base.y + number())
                path.addLine(to: current)
            case "H":
                current.x = (relative ? current.x : 0) + number()
                path.addLine(to: current)
            case "V":
                current.y = (relative ? current.y : 0) + number()
                path.addLine(to: current)
            case "A":
                let r = number()
                _ = number() // ry: the icons only use circular arcs
                _ = number() // x-axis rotation
                let largeArc = number() != 0
                let sweep = number() != 0
                let end = CGPoint(x: base.x + number(), y: base.y + number())
                addArc(to: &path, from: current, to: end, radius: r, largeArc: largeArc, sweep: sweep)
                current = end
            case "Z":
                path.closeSubpath()
                current = start
                if !hasNumber() { continue }
            default:
                _ = tokens.popFirst()
            }
        }
    }

    /// SVG endpoint arc to points (SVG spec F.6.5, circular case), sampled
    /// finely enough to be smooth at icon sizes.
    private static func addArc(to path: inout Path, from p0: CGPoint, to p1: CGPoint, radius: CGFloat, largeArc: Bool, sweep: Bool) {
        let dx = (p0.x - p1.x) / 2
        let dy = (p0.y - p1.y) / 2
        var r = radius
        let lambda = (dx * dx + dy * dy) / (r * r)
        if lambda > 1 { r *= lambda.squareRoot() }
        let sign: CGFloat = largeArc != sweep ? 1 : -1
        let numerator = max(0, r * r * r * r - r * r * dy * dy - r * r * dx * dx)
        let coefficient = sign * (numerator / (r * r * dy * dy + r * r * dx * dx)).squareRoot()
        let cxPrime = coefficient * dy
        let cyPrime = -coefficient * dx
        let centre = CGPoint(x: cxPrime + (p0.x + p1.x) / 2, y: cyPrime + (p0.y + p1.y) / 2)
        let start = atan2((dy - cyPrime) / r, (dx - cxPrime) / r)
        let end = atan2((-dy - cyPrime) / r, (-dx - cxPrime) / r)
        var delta = end - start
        if sweep, delta < 0 { delta += 2 * .pi }
        if !sweep, delta > 0 { delta -= 2 * .pi }
        let samples = max(8, Int(abs(delta) / (.pi / 36)))
        for i in 1...samples {
            let t = start + delta * CGFloat(i) / CGFloat(samples)
            path.addLine(to: CGPoint(x: centre.x + r * cos(t), y: centre.y + r * sin(t)))
        }
    }

    private enum Token {
        case command(Character)
        case number(CGFloat)
    }

    private static func tokenize(_ d: String) -> [Token] {
        var tokens: [Token] = []
        var numberText = ""
        func flush() {
            if let n = Double(numberText) { tokens.append(.number(CGFloat(n))) }
            numberText = ""
        }
        for ch in d {
            if ch.isLetter {
                flush()
                tokens.append(.command(ch))
            } else if ch == "-" {
                flush()
                numberText = "-"
            } else if ch == "." && numberText.contains(".") {
                flush()
                numberText = "."
            } else if ch.isNumber || ch == "." {
                numberText.append(ch)
            } else {
                flush()
            }
        }
        flush()
        return tokens
    }
}
