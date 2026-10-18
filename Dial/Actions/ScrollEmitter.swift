import CoreGraphics

/// Posts line-based scroll events at the pointer. Needs Accessibility.
enum ScrollEmitter {
    /// Positive `lines` scrolls down (or right, when horizontal).
    static func scroll(lines: Int, horizontal: Bool) {
        // Wheel values are positive for up and left.
        let amount = Int32(-lines)
        let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 2,
            wheel1: horizontal ? 0 : amount,
            wheel2: horizontal ? amount : 0,
            wheel3: 0
        )
        event?.post(tap: .cghidEventTap)
    }
}
