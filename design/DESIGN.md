# Dial: design spec for the native build

This is the single page to build the UI from. The other files in `design/` go deeper:

- `tokens.json` is the source of every value. `DialTokens.swift` is generated from it; copy it into the app and don't hand-edit values.
- `brand-book.md` covers the principles and the colour rules.
- `motion.md` has the full choreography.
- `components/*.md` hold each component's rules.
- `reference/*.html` are interactive browser previews (arrow keys turn, Space presses, D double presses). Open them to see the intended motion.
- `reference/screenshots/*.png` show every key state in dark and light. Compare your SwiftUI previews against these.

The HTML references are for looks and timing only. Don't port their code. Build natively in SwiftUI.

## Modes

Nine segments, clockwise from the gap at 12 o'clock. Segment index, id and SF Symbol suggestion in brackets; the custom line icons in the references can replace the symbols later.

| # | Mode | Kind | Turn | Press |
|---|---|---|---|---|
| 0 | Volume (`speaker.wave.2`) | level | volume down / up (pass-through) | mute |
| 1 | Brightness (`sun.max`) | level | dimmer / brighter | Night Shift |
| 2 | Apps (`square.grid.3x3`) | list | move through the app fan | open the app |
| 3 | Mission Control (`rectangle.3.group`) | list | opens Mission Control, then moves between windows | bring window forward |
| 4 | Desktops (`rectangle.on.rectangle`) | step | previous / next desktop | show desktop |
| 5 | Tabs (`macwindow`) | step | previous / next tab | new tab |
| 6 | Scroll (`computermouse`) | step | 3 lines up / down per detent | switch to sideways |
| 7 | Undo / Redo (`arrow.uturn.backward`) | step | left undoes, right redoes | save |
| 8 | Slides (`play.rectangle`) | step | previous / next slide | start / end show |

Short knob labels: Volume, Bright, Apps, Mission, Desktops, Tabs, Scroll, Undo, Slides.

## Colour

Dark is primary. The ring, knob and accent are identical in both themes; only the ground, well, cards and text change. Use `DialColor.*`, which resolves per appearance.

| Token | Dark | Light | Use |
|---|---|---|---|
| ring | #2a2c31 | #2c2e33 | ring body |
| ring-well | #141518 | #ececea | recess between ring and knob |
| ring-divider | #3a3c42 | #3c3e44 | 1pt lines between segments |
| segment-active | #4a4d54 | #5a5d64 | lifted selected segment |
| segment-hatch | #5c5f67 | #6b6e75 | 45° stripes on the selected segment |
| icon-idle | #9d9fa5 | #a3a5aa | resting icons |
| icon-active | #ffffff | #ffffff | selected icon |
| knob-face → knob-shade | #f3f3f1 → #d6d6d2 | same | knob radial gradient, light at top left |
| knob-knurl | #b9b9b4 | same | knurled band; teeth drawn in knob-face |
| knob-ink | #26304f | same | pointer marks, knob icon and label |
| glow | #ff7b3d | same | rim light and press pulse only |
| focus | #ff7b3d | #c2531f | keyboard focus |
| ink / ink-muted | #e8e9ec / #8e9197 | #1d1e22 / #5f6167 | text |
| card / card-active | #26282d / #30333a | #ffffff / #f1f1ef | HUD, app cards |
| card-border / -active | #3a3d44 / #6a6e77 | #d6d6d2 / #9a9da3 | card edges, connector line |
| hairline | #2f3136 | #d0d0cc | meter track |

## Dial geometry

Draw in a 260 × 260 pt space, centre (130, 130), angles clockwise from 12 o'clock (`DialGeometry`).

- **Ring**: annulus from r 68 to r 112, with a 48° gap centred on 12 o'clock, so it spans 24° to 336°. The two ends at the gap have 10pt rounded corners. One easy way to get them: build the sector inset by 10pt (radii 78 to 102, angles pulled in by asin(10 / 90)), then fill it and stroke it 20pt wide with a round line join in the same colour. Shadow: `DialShadow.ring`.
- **Segments**: nine of (360 − 48) / 9 = 34.67° each. Segment i is centred on 24 + 34.67 × (i + 0.5). Draw 1pt `ringDivider` lines on the boundaries, from r 75 to r 105.
- **Selected segment**: sector from r 67 to r 118 (lifted 6pt past the ring), 6pt rounded corners, `segmentActive` fill with `segmentHatch` stripes at 45°: 1.6pt stripes on a 5pt pitch, at 60% opacity. Draw it once at segment 0 and rotate it, so it animates as rotation.
- **Icons**: 18pt, centred on r 90, always upright, 1.5pt stroke. `iconIdle`, or `iconActive` when selected.
- **Well**: circle r 62, `ringWell`.
- **Knob**: r 49.
  - Outer 4pt band is `knobKnurl`, with 90 radial teeth (one every 4°), 1.1pt `knobFace` lines from r 45.4 to r 48.4.
  - Face: circle r 44 with a radial gradient from `knobFace` (centre at 38%, 32%) to `knobShade`.
  - Inner rim: circle r 38, 1pt `knobShade` stroke.
  - Rim light: a 2pt `glow` arc at 55% opacity on r 43.5, from 280° to 345° (upper left). It doesn't rotate.
  - Pointer marks: two 2pt round-capped `knobInk` lines from r 34 to r 41, at 0° and 180°. These copy the two engraved lines on the CMF case's dial. The knob rotates so the 0° mark points at the selected segment's centre angle.
  - Label (upright, never rotates): the mode icon at 18pt centred at (130, 116), and the short name in `DialFont.knobLabel` centred on y 141. Both in `knobInk`.
  - Shadow: `DialShadow.knob`, tightening to `.knobPressed` on press.
- **Tether dot**: r 2.5, `glow`, at (130, 22), inside the gap. It sits under the menu bar glyph.

## Angles must accumulate

Keep the highlight and knob angles as running totals; never set them modulo 360. One detent adds ±34.67°. Wrapping from Slides to Volume (or back) adds ±(34.67 + 48)°, so the highlight jumps across the gap in the turning direction instead of spinning the long way round.

## The menu bar item and panels

- The status item shows a 15pt ring glyph plus the current mode's name in `DialFont.hudLabel`. While the dial is open, the item gets a `cardActive` rounded highlight.
- The dial lives in a borderless, non-activating `NSPanel` at status-bar level, with a transparent background, joining all Spaces. It's positioned so the dial's centre x equals the glyph's centre x, and the ring's top edge is 16pt (`space-4`) below the menu bar.
- The HUD is a second non-activating panel, centred under the glyph, 12pt below the bar.
- Neither panel ever becomes key or steals focus from the app being controlled.

## HUD pill

- 34pt tall, capsule, `card` fill, 1pt `cardBorder`, `DialShadow.card`.
- Contents: 16pt icon, label (`hudLabel`), then either a 72 × 4pt meter (`hairline` track, `ink` fill) for levels, or a value string in `hudValue` (`ink-muted`), such as `3 / 8`, `Undo ×2` or `↓ 6 lines`.
- Every turn restarts a 1.2s linger. The value nudges up 2pt and back on change.
- A press shows the press action's name ("Mute") in the value slot.
- In Mission Control the HUD stays while it's open, at the bottom centre of the screen.

## App fan (Apps mode)

- The dial stays open. The ring stops moving; only the knob turns, 24° per detent.
- Cards are 208 × 44pt, `radiusMd`, `card` fill with `cardBorder` and `DialShadow.card`. Each has a 26pt app icon tile, the name in `cardTitle` and `⌘n` in `cardMeta`.
- They're laid out on an arc around the dial centre: radius 160pt, base angle 4° below horizontal, 12° between cards. Each card rotates with the arc.
- The selected card sits on the base angle in `cardActive` with a `cardBorderActive` edge. Neighbours step to 62%, 32% and 12% opacity at 95% size; hide beyond ±3.
- A 1pt `cardBorderActive` connector with an elbow runs from the selected segment's outer edge (r 118) to the selected card's leading edge, with a 2.5pt dot at the segment end.
- Order is most recently used first, and the list wraps.

## Mission Control

- Try the real Mission Control first: open it, then send arrow keys while the user turns. If that can't move the selection, build Dial's own picker with the look in `reference/screenshots/mission-spread-*.png`.
- **Fallback picker look**: windows dealt out from their real frames into a grid, using ScreenCaptureKit thumbnails. The selected window gets a 2pt `cardBorderActive` ring, 103% scale and its title in a capsule (`ring` fill, `iconActive` text) beneath it. A desktops strip sits along the top.

## Motion (all in `DialMotion`)

| Moment | What moves | Timing |
|---|---|---|
| Summon (double press) | panel content from y −28, 70% scale, 6pt blur, 0 opacity, scaling from top centre; icons pop from 40% scale 18ms apart clockwise; knob turns in from −90° at 80% scale | `summon` 320ms, `summonKnob` 460ms |
| Detent | highlight rotates one segment, knob rotates to match, new icon ticks 100 → 118 → 100%, knob label swaps (rise 4pt, fade in) | `detent` 160ms; `labelSwap` 180ms |
| Fast spin | steps under 70ms apart use linear 70ms until 160ms of quiet | `detentFast` |
| Press | knob to 92% scale with the pressed shadow, then springs back; glow ring scales 1 → 1.24 and fades from 0.9 to 0; the selected segment flashes from `iconIdle` back to `segmentActive` | `pressDown` 90ms, `pressUp` 220ms, `glowPulse` 560ms |
| Choose | 170ms after the press the dial folds back up (reverse of summon, no stagger); the menu bar label swaps; HUD appears 120ms later | `dismiss` 180ms |
| Idle | dial closes after 4s without input | `idleDismiss` |
| HUD | in from y −8 at 90% scale; out with ease-in | `hud` 200ms |
| Fan | cards ripple along the arc, 24ms per step away from the axis | `fanCards` 260ms |
| Mission | windows deal out 22ms apart; reverse with no stagger | `missionDeal` 380ms |

With Reduce Motion on, every change is instant: no blur, scale, ticks or glow pulse. Colour still marks the selection.
