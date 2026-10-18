# Dial

Dial turns the Smart Dial on the CMF Buds Pro 2 case into a control surface for the Mac. It lives in the menu bar. A double press drops a radial wheel of modes out of the menu bar item; you turn to pick a mode, press to choose it, and from then on every turn drives that mode until you double press again. "Dial" is a working name.

## What it looks like and why

The look comes from reference shots of a radial quick-access dial: a dark, segmented C-shaped ring around a white, knurled knob, with one segment lifted and hatched, and cards that fan out on an arc. Dial keeps that object-like quality and changes three things:

- **No brand mark in the gap.** The ring's opening now faces the menu bar item the dial hangs from, with a small warm tether dot in it.
- **The knob is the hardware.** Its two pointer marks copy the two lines engraved on the CMF case's dial, and they rotate to point at what you've picked. What your thumb does and what the screen shows always agree.
- **Warm light, used once.** The only colour is `glow`, an orange rim light on the knob that pulses outward when you press. Everything else is greyscale.

## Principles

1. **Physical first.** Every input from the buds gets a visible, mechanical-feeling answer: a detent step, a knob that sinks, a value that nudges.
2. **One gesture, one motion.** A turn moves one thing by one step. A press does one thing. Nothing animates that you didn't cause, except the idle close.
3. **A quiet ring and a bright selection.** Icons rest in `icon-idle`; only the active segment gets `segment-active`, the hatch and `icon-active`.
4. **Out of the way by default.** The dial shows only while you pick. Inside a mode, all you see is a 34px HUD pill that fades 1.2s after the last turn.

## The modes

Nine modes, clockwise from the gap:

| Mode | Kind | Turn does | Press does |
|---|---|---|---|
| Volume | Level | Volume down / up | Mute |
| Brightness | Level | Dimmer / brighter | Night Shift |
| Apps | List | Move through open apps on a card fan | Open the app |
| Mission Control | List | Opens Mission Control, then moves between windows | Bring the window forward |
| Desktops | Step | Previous / next desktop | Show desktop |
| Tabs | Step | Previous / next tab in the front app | New tab |
| Scroll | Step | Scroll up / down, 3 lines per detent | Switch to sideways |
| Undo / Redo | Step | Turn left undoes, turn right redoes | Save |
| Slides | Step | Previous / next slide | Start / end the show |

The press actions are suggestions to review; each can be changed per mode in settings.

## What the buds actually send

The dial on the case talks to the earbuds, and the earbuds send standard headphone commands to the Mac. Dial reads three of them:

- **Turn** arrives as a change in the buds' volume. In Volume mode it passes through. In every other mode Dial turns each change into one step and sets the volume back.
- **Press** arrives as play/pause (set this in the Nothing X app).
- **Double press** arrives as next track (set this in Nothing X too). It opens and closes the dial.

## Colour

Greyscale plus one warm accent. Themes are **Dark** (primary) and **Light**; the ring, knob and accent are the same in both, and only the ground, well, cards and text flip.

- `ring` is always dark. It is an object sitting on the screen, not a surface of it.
- `segment-active` + `segment-hatch` mark the one live segment. Never use them for anything else.
- `knob-face` → `knob-shade` is the knob's gradient; `knob-ink` is the only colour drawn on it.
- `glow` is the rim light and press pulse. Never text, never a background, never larger than the knob.
- `ink` and `ink-muted` carry all text on `canvas`, `card` and `menubar`. Every pair passes 4.5:1; `focus` passes 3:1 against `canvas` in both themes.

## Type

The Mac's own San Francisco (`-apple-system`), so Dial sits naturally in the menu bar; Inter stands in on other systems. Numbers and positions use SF Mono (JetBrains Mono as fallback) so values don't jitter as they change.

- `knob-label` 10/12 semibold: one short word on the knob.
- `hud-label` 12/16 semibold and `hud-value` 12/16 mono: the HUD pill and the menu bar label.
- `card-title` 14/20 and `card-meta` 11/14 mono: app cards and window titles.
- `title`, `body`, `caption`: the settings window.

## Iconography

Line icons on a 24px grid, 1.5px stroke (`icon-stroke`), round caps and joins, no fills, drawn at 18px on the ring and 16px in the HUD. One icon per mode:

- Volume: speaker with two waves
- Brightness: sun
- Apps: 3 × 3 dots
- Mission Control: two windows under an up chevron, the swipe up
- Desktops: a screen with a second behind it
- Tabs: a window with a tab
- Scroll: a mouse with its wheel
- Undo / Redo: a curved return arrow
- Slides: a screen on a stand with a play mark

App cards use the real app icons in the app; the previews draw letter tiles instead.

## Shape and space

- The dial is drawn on a 260px square: ring radius 68–112px, a 48° gap at the top, the active segment lifted 6px, a 49px knob. All of it is in the `geometry` tokens.
- Cards and window thumbnails use `radius-md`; chips use `radius-sm`; the HUD and the menu bar label use `radius-pill`.
- Spacing runs 4, 8, 12, 16, 24, 32 (`space-1` to `space-8`). The dial hangs `space-4` below the menu bar.

## Motion

Every transition, with its duration and easing, is in the **Motion** section. The short version: detents settle in 160ms with a click-like overshoot, the knob sinks in 90ms and springs back in 220ms, and the dial drops in 320ms and retracts in 180ms.

## Components

- **Dial**: the ring and knob, with every turn and press state.
- **MenuBarDrop**: the full loop, from menu bar item to dial, back to the bar, and the HUD.
- **ModeHUD**: the pill for levels, steps and lists.
- **AppFan**: Apps mode's card fan.
- **MissionControl**: Mission Control mode's window spread and selection.

Every preview runs with the arrow keys, Space (press), D (double press) or a trackpad scroll standing in for the real dial.
