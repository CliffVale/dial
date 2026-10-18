import SwiftUI

/// Chips, as in the reference review controls: `card` fill, a `cardBorder`
/// hairline, `radius-sm`, `cardActive` while pressed.
struct DialChipButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(DialColor.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: DialRadius.sm)
                    .fill(configuration.isPressed || prominent ? DialColor.cardActive : DialColor.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DialRadius.sm)
                    .strokeBorder(prominent ? DialColor.cardBorderActive : DialColor.cardBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

/// An uppercase `caption` heading over a section.
struct SectionCaption: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(DialFont.caption)
            .tracking(0.66)
            .foregroundStyle(DialColor.inkMuted)
    }
}

/// A `canvasRaised` panel with `radius-md` corners and a hairline edge.
struct RaisedPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: DialRadius.md).fill(DialColor.canvasRaised))
            .overlay(RoundedRectangle(cornerRadius: DialRadius.md).strokeBorder(DialColor.hairline, lineWidth: 1))
    }
}

/// A small status mark: a filled check when done, a ring when not yet.
struct StatusMark: View {
    let done: Bool

    var body: some View {
        Image(systemName: done ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(done ? DialColor.ink : DialColor.inkMuted)
    }
}
