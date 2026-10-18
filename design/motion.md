# Motion

Dial moves like a physical control: short, decisive steps that settle with a slight click, and nothing moving that your hand didn't start. Durations and curves are tokens (`dur-*`, `ease-*`); this page is the choreography.

## Curves

| Token | Value | Used for |
|---|---|---|
| `ease-detent` | cubic-bezier(0.25, 1.25, 0.5, 1) | Highlight and knob steps. A small overshoot that reads as a click. |
| `ease-spring` | cubic-bezier(0.34, 1.36, 0.64, 1) | Knob release, icon tick, fan cards, the dial's arrival. |
| `ease-out` | cubic-bezier(0.2, 0.9, 0.25, 1) | Things arriving: fades, the HUD, glow. |
| `ease-in` | cubic-bezier(0.4, 0, 1, 1) | Things leaving, and the knob sinking. |

In SwiftUI these map to `.spring(response: 0.18, dampingFraction: 0.62)` for detents, `.spring(response: 0.3, dampingFraction: 0.68)` for release and arrival, `.easeOut(duration: 0.2)` and `.easeIn(duration: 0.18)`.

## Summon: double press

| What | From → to | Time | Curve |
|---|---|---|---|
| Menu bar item | open highlight on | 160ms | ease |
| Dial | y −28px, 70% scale, 6px blur, transparent → in place | 320ms | ease-spring (scale), ease-out (fade, blur) |
| Transform origin | top centre, the gap under the glyph | | |
| Segment icons | 40% scale, transparent → full | 240ms each, 18ms apart clockwise | ease-spring |
| Knob | −90°, 80% scale → resting angle | 460ms | ease-spring |
| HUD (if showing) | out | 200ms | ease-in |

The dial seems to drop out of the menu bar and unwind into place, and the icons arrive in the order you'd turn through them.

## Turn: one detent

| What | Change | Time | Curve |
|---|---|---|---|
| Active segment | rotates one segment (≈34.7°); across the gap it travels segment + gap | 160ms | ease-detent |
| Knob face | turns to point at the new segment | 160ms | ease-detent |
| New icon | idle → active colour, then a tick: 100% → 118% → 100% | 140ms colour, 160ms tick | ease, ease-spring |
| Knob label | old one swaps out; new one rises 4px and fades in | 180ms | ease-out |

**Fast spins.** If detents arrive less than 70ms apart, steps switch to 70ms linear (`dur-detent-fast`) so the highlight keeps up with your thumb instead of lagging behind a queue of springs. It returns to normal 160ms after the spin stops.

## Press: choose

| What | Change | Time | Curve |
|---|---|---|---|
| Knob | 100% → 92%, shadow tightens to `shadow-knob-pressed` | 90ms down | ease-in |
| Knob | back to 100% | 220ms up | ease-spring |
| Glow ring | from the knob's edge, 100% → 124%, opacity 0.9 → 0 | 560ms | ease-out |
| Active segment | flashes to `icon-idle` and settles back to `segment-active` | 360ms | ease-out |
| Dial | folds back into the menu bar, starting 170ms after the press | 180ms | ease-in |
| Menu bar label | swaps to the new mode | 220ms | ease-out |
| HUD | shows the mode's current value, 120ms after the label | 200ms | ease-spring |

## Inside a mode

- **Turn**: HUD meter or value updates in 160ms; the value nudges up 2px and back (180ms, ease-spring). The HUD lingers 1.2s after the last turn, then leaves in 200ms ease-in.
- **Apps**: cards rotate along the fan arc in 260ms on ease-spring, each 24ms later than the one nearer the axis, so the fan ripples outward. The knob turns 24° per detent.
- **Mission Control**: windows deal out from stacked to spread in 380ms ease-spring, 22ms apart; the selection ring hops instantly, and the selected window eases to 103% over 380ms.

## Dismiss

- Idle for 4s (`idle-dismiss`), or a second double press: the dial retracts to y −28px at 70% scale with blur, 180ms ease-in. The icons vanish together, without a stagger. Leaving should be quicker than arriving.

## Reduced motion

With Reduce Motion on, every transition becomes a 1ms change: no blur, no scale, no ticks, no glow pulse. Colour still marks the active segment, so nothing is lost but the movement.
