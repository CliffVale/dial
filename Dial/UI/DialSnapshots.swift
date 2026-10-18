import AppKit
import SwiftUI

/// `Dial --snapshots <folder>` renders the dial at 2x, framed like
/// design/reference/screenshots/dial-*.png (a 720 × 440pt canvas with the
/// dial's centre at 360, 160), then quits. For comparing against the references.
@MainActor
enum DialSnapshots {
    static let argument = "--snapshots"

    static func renderIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: argument), args.indices.contains(flag + 1) else { return false }
        let folder = URL(fileURLWithPath: args[flag + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        for (name, mode) in [("rest", ModeID.volume), ("mission-selected", .missionControl), ("bright", .brightness)] {
            for scheme in [ColorScheme.dark, .light] {
                let file = folder.appendingPathComponent("dial-\(name)-\(scheme == .dark ? "dark" : "light").png")
                render(DialPreviewCanvas(selection: mode), scheme: scheme, to: file)
            }
        }
        return true
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
