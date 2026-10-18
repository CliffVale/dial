// DialTokens.swift
// Generated from design/tokens.json. If a token changes, regenerate this file
// rather than editing values by hand.

import SwiftUI
import AppKit

// MARK: - Colour

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
                  green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255,
                  alpha: alpha)
    }
}

extension Color {
    /// A colour that follows the system appearance: Dark first, Light second.
    init(dark: UInt32, light: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

enum DialColor {
    /// The desktop ground behind the dial in previews and settings. Never used inside the dial.
    static let canvas = Color(dark: 0x18191c, light: 0xe6e6e3)
    /// Settings window panels and preview stages that sit on canvas.
    static let canvasRaised = Color(dark: 0x202125, light: 0xf4f4f2)
    /// The C-shaped ring body. Stays dark in both themes: the ring is an object, not a surface.
    static let ring = Color(dark: 0x2a2c31, light: 0x2c2e33)
    /// The recessed well between the ring and the knob. Darker than ring in dark, near-white in light, so the knob always reads as raised.
    static let ringWell = Color(dark: 0x141518, light: 0xececea)
    /// 1px hairlines between ring segments. Decorative, no contrast requirement.
    static let ringDivider = Color(dark: 0x3a3c42, light: 0x3c3e44)
    /// The lifted, highlighted segment. Pairs with icon-active (8.5:1 dark, 6.6:1 light).
    static let segmentActive = Color(dark: 0x4a4d54, light: 0x5a5d64)
    /// 45° stripes laid over segment-active. Texture only.
    static let segmentHatch = Color(dark: 0x5c5f67, light: 0x6b6e75)
    /// Resting segment icons on ring (5.3:1 dark, 5.5:1 light).
    static let iconIdle = Color(dark: 0x9d9fa5, light: 0xa3a5aa)
    /// The icon on segment-active.
    static let iconActive = Color(dark: 0xffffff, light: 0xffffff)
    /// Knob face highlight, the top-left of its radial gradient.
    static let knobFace = Color(dark: 0xf3f3f1, light: 0xf3f3f1)
    /// Knob face shadow side and the inner rim line.
    static let knobShade = Color(dark: 0xd6d6d2, light: 0xd6d6d2)
    /// The knurled outer band of the knob; its teeth are knob-face lines on top.
    static let knobKnurl = Color(dark: 0xb9b9b4, light: 0xb9b9b4)
    /// Pointer marks, icon and label on the knob face (11.7:1 on knob-face).
    static let knobInk = Color(dark: 0x26304f, light: 0x26304f)
    /// The warm rim light on the knob and the press pulse. Never text, never a fill larger than the knob.
    static let glow = Color(dark: 0xff7b3d, light: 0xff7b3d)
    /// Keyboard focus rings (6.8:1 dark, 3.7:1 light against canvas).
    static let focus = Color(dark: 0xff7b3d, light: 0xc2531f)
    /// Primary text on canvas, card and menubar.
    static let ink = Color(dark: 0xe8e9ec, light: 0x1d1e22)
    /// Secondary text and values on canvas and card (4.6:1 or better).
    static let inkMuted = Color(dark: 0x8e9197, light: 0x5f6167)
    /// Mode HUD pill, app cards, control chips.
    static let card = Color(dark: 0x26282d, light: 0xffffff)
    /// The selected card in the app fan and hovered chips.
    static let cardActive = Color(dark: 0x30333a, light: 0xf1f1ef)
    /// 1px border on cards and chips.
    static let cardBorder = Color(dark: 0x3a3d44, light: 0xd6d6d2)
    /// Border of the selected card, and the connector line to it.
    static let cardBorderActive = Color(dark: 0x6a6e77, light: 0x9a9da3)
    /// Meter tracks and dividers in the HUD and settings.
    static let hairline = Color(dark: 0x2f3136, light: 0xd0d0cc)
    /// The mock macOS menu bar in previews.
    static let menubar = Color(dark: 0x1f2023, light: 0xf2f2f0)
}

// MARK: - Geometry
// The dial is drawn in a 260 x 260 pt square, centre (130, 130).
// Angles run clockwise from 12 o'clock.

enum DialGeometry {
    static let canvas: CGFloat = 260
    static let ringOuterRadius: CGFloat = 112
    static let ringInnerRadius: CGFloat = 68
    static let ringGapDegrees: Double = 48
    static let ringEndCornerRadius: CGFloat = 10   // radius-md
    static let segmentLift: CGFloat = 6
    static let segmentCornerRadius: CGFloat = 6    // radius-sm
    static let wellInset: CGFloat = 6              // well radius = inner radius - 6
    static let knobRadius: CGFloat = 49
    static let knurlBand: CGFloat = 4
    static let knurlTeeth = 90                     // one tooth every 4 degrees
    static let knobDetentDegrees: Double = 24
    static let iconSize: CGFloat = 18
    static let iconRadius: CGFloat = 90            // icon centres sit on this radius
    static let iconStroke: CGFloat = 1.5
    static let segmentCount = 9

    static var segmentDegrees: Double { (360 - ringGapDegrees) / Double(segmentCount) }

    /// Centre angle of segment i, clockwise from 12 o'clock.
    static func centreAngle(_ i: Int) -> Double {
        ringGapDegrees / 2 + segmentDegrees * (Double(i) + 0.5)
    }
}

// MARK: - Spacing and radius

enum DialSpace {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32
}

enum DialRadius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
    static let pill: CGFloat = 999
}

// MARK: - Type (San Francisco; SF Mono for values)

enum DialFont {
    static let knobLabel = Font.system(size: 10, weight: .semibold)      // tracking 0.2
    static let hudLabel = Font.system(size: 12, weight: .semibold)
    static let hudValue = Font.system(size: 12, weight: .medium, design: .monospaced)
    static let cardTitle = Font.system(size: 14, weight: .medium)
    static let cardMeta = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let title = Font.system(size: 22, weight: .semibold)          // tracking -0.22
    static let body = Font.system(size: 13, weight: .regular)
    static let caption = Font.system(size: 11, weight: .medium)          // uppercase, tracking 0.66
}

// MARK: - Shadow

struct DialShadow {
    let y: CGFloat
    let radius: CGFloat
    let darkOpacity: Double
    let lightOpacity: Double
}

extension DialShadow {
    /// Under the whole dial: it floats below the menu bar. CSS blur 48px; SwiftUI radius is about half.
    static let ring = DialShadow(y: 24, radius: 24, darkOpacity: 0.45, lightOpacity: 0.28)
    /// Knob at rest. On press it tightens to shadow-knob-pressed. CSS blur 14px; SwiftUI radius is about half.
    static let knob = DialShadow(y: 8, radius: 7, darkOpacity: 0.40, lightOpacity: 0.30)
    /// Knob held down. CSS blur 4px; SwiftUI radius is about half.
    static let knobPressed = DialShadow(y: 2, radius: 2, darkOpacity: 0.40, lightOpacity: 0.30)
    /// HUD pill and app cards. CSS blur 16px; SwiftUI radius is about half.
    static let card = DialShadow(y: 6, radius: 8, darkOpacity: 0.30, lightOpacity: 0.10)
}

// MARK: - Motion

enum DialMotion {
    /// One detent of the highlight and the knob: 160 ms with a small overshoot.
    static let detent = Animation.spring(response: 0.18, dampingFraction: 0.62)
    /// Detents arriving under 70 ms apart switch to this.
    static let detentFast = Animation.linear(duration: 0.07)
    static let fastStepThreshold: TimeInterval = 0.07
    static let fastStepCooldown: TimeInterval = 0.16
    static let pressDown = Animation.easeIn(duration: 0.09)
    static let pressUp = Animation.spring(response: 0.22, dampingFraction: 0.6)
    static let pressScale: CGFloat = 0.92
    /// Glow ring: scale 1 -> 1.24, opacity 0.9 -> 0.
    static let glowPulse = Animation.easeOut(duration: 0.56)
    static let summon = Animation.spring(response: 0.32, dampingFraction: 0.72)
    /// Knob arrives from -90 degrees at 0.8 scale.
    static let summonKnob = Animation.spring(response: 0.46, dampingFraction: 0.7)
    static let dismiss = Animation.easeIn(duration: 0.18)
    static let iconStagger: TimeInterval = 0.018
    static let labelSwap = Animation.easeOut(duration: 0.18)
    static let hud = Animation.spring(response: 0.2, dampingFraction: 0.75)
    static let hudLinger: TimeInterval = 1.2
    static let chooseFoldDelay: TimeInterval = 0.17
    static let idleDismiss: TimeInterval = 4.0
    static let fanCards = Animation.spring(response: 0.26, dampingFraction: 0.7)
    static let fanStagger: TimeInterval = 0.024
    static let missionDeal = Animation.spring(response: 0.38, dampingFraction: 0.72)
    static let missionStagger: TimeInterval = 0.022
}
