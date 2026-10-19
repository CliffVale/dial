import AppKit
import SwiftUI

/// `Dial --snapshots <folder>` renders the dial at 2x, framed like
/// design/reference/screenshots/dial-*.png (a 720 × 440pt canvas with the
/// dial's centre at 360, 160), then quits. For comparing against the references.
@MainActor
enum DialSnapshots {
    static let argument = "--snapshots"

    static let iconArgument = "--app-icon"

    static func renderIfRequested() -> Bool {
        let args = CommandLine.arguments
        if let flag = args.firstIndex(of: iconArgument), args.indices.contains(flag + 1) {
            renderAppIcon(to: URL(fileURLWithPath: args[flag + 1]))
            return true
        }
        guard let flag = args.firstIndex(of: argument), args.indices.contains(flag + 1) else { return false }
        let folder = URL(fileURLWithPath: args[flag + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        for (name, mode) in [("rest", ModeID.volume), ("mission-selected", .missionControl), ("bright", .brightness)] {
            for scheme in [ColorScheme.dark, .light] {
                let file = folder.appendingPathComponent("dial-\(name)-\(scheme == .dark ? "dark" : "light").png")
                render(DialPreviewCanvas(selection: mode), scheme: scheme, to: file)
            }
        }
        // Framed like hud-volume-*.png: the pill centred at 360, 106 on a 720 × 220pt canvas.
        let volume = HUDContent(mode: .volume, reading: HUDReading(level: 0.68, text: "68"), afterChoose: false)
        let tabs = HUDContent(mode: .tabs, reading: HUDReading(level: nil, text: "Next ×2"), afterChoose: false)
        for (name, content) in [("volume", volume), ("tabs", tabs)] {
            for scheme in [ColorScheme.dark, .light] {
                let file = folder.appendingPathComponent("hud-\(name)-\(scheme == .dark ? "dark" : "light").png")
                let view = HUDPreview(content: content).presentationView
                    .position(x: 360, y: 106)
                    .frame(width: 720, height: 220)
                    .background(DialColor.canvas)
                render(view, scheme: scheme, to: file)
            }
        }
        // Framed like appfan-*.png: the dial's centre at 164, 176 on a 720 × 440pt canvas.
        let switcher = AppSwitcher()
        switcher.start()
        let apps = AppsMode(switcher: switcher)
        apps.refresh()
        apps.turn(2)
        for scheme in [ColorScheme.dark, .light] {
            let model = DialModel.previewFan(apps: apps)
            let presentation = DialPresentation()
            presentation.isShown = true
            let view = ZStack(alignment: .topLeading) {
                AppFanView(apps: apps, isOpen: true, segmentAngle: DialGeometry.centreAngle(2), pressCount: 0)
                    .offset(x: 164, y: 176)
                DialView(model: model, presentation: presentation)
                    .offset(x: 164 - 130, y: 176 - 130)
            }
            .frame(width: 720, height: 440, alignment: .topLeading)
            .background(DialColor.canvas)
            render(view, scheme: scheme, to: folder.appendingPathComponent("appfan-\(scheme == .dark ? "dark" : "light").png"))
        }
        return true
    }

    /// `Dial --app-icon <file.png>`: the 1024px app icon, always in the dark
    /// look, the primary theme. Smaller sizes are scaled down from it.
    private static func renderAppIcon(to url: URL) {
        let appearance = NSAppearance(named: .darkAqua)!
        appearance.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(content: AppIconView().environment(\.colorScheme, .dark))
            renderer.scale = 1
            guard let image = renderer.cgImage else { return }
            try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: url)
        }
    }

    private static func render<V: View>(_ view: V, scheme: ColorScheme, to url: URL) {
        let appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)!
        appearance.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(content: view.environment(\.colorScheme, scheme))
            renderer.scale = 2
            guard let image = renderer.cgImage else { return }
            let rep = NSBitmapImageRep(cgImage: image)
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
        }
    }
}

private struct DialPreviewCanvas: View {
    let selection: ModeID

    var body: some View {
        let preview = DialPreview(selection: selection)
        DialView(model: preview.model, presentation: preview.presentation)
            .position(x: 360, y: 160)
            .frame(width: 720, height: 440)
            .background(DialColor.canvas)
    }
}


/// The app icon: the dial itself, Volume selected, on a `canvasRaised` tile in
/// the macOS icon grid (an 824pt rounded square on a 1024pt canvas).
struct AppIconView: View {
    private static let tile: CGFloat = 824
    /// The dial fills most of the tile, leaving room for the ring's shadow.
    private static let dialScale: CGFloat = 0.9 * tile / DialGeometry.canvas

    var body: some View {
        let preview = DialPreview(selection: .volume)
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(DialColor.canvasRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: 185, style: .continuous)
                        .strokeBorder(DialColor.hairline, lineWidth: 4)
                )
                .frame(width: Self.tile, height: Self.tile)
                .shadow(color: .black.opacity(0.3), radius: 14, y: 10)
            DialView(model: preview.model, presentation: preview.presentation, showsKnobLabel: false)
                .scaleEffect(Self.dialScale)
                .offset(y: 8)
        }
        .frame(width: 1024, height: 1024)
    }
}
