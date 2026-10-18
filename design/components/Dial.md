# Dial

The radial mode picker: a dark C-shaped ring of nine segments around a white, knurled knob that mirrors the physical Smart Dial.

## Anatomy

- **Ring** (`ring`): a C with a 48° opening at 12 o'clock (`ring-gap`). The opening faces the menu bar item the dial drops from; a small `glow` dot sits in it as the tether point. The two ends at the gap round off at `radius-md`.
- **Segments**: nine equal sectors, split by 1px `ring-divider` lines, each with an 18px line icon in `icon-idle`.
- **Active segment**: `segment-active` with 45° `segment-hatch` stripes, lifted 6px past the ring's outer edge (`segment-lift`). Its icon turns `icon-active`.
- **Well** (`ring-well`): the recess between ring and knob, so the knob always reads as raised.
- **Knob**: a 4px knurled band (`knob-knurl` with `knob-face` teeth), a face gradient from `knob-face` to `knob-shade`, an inner rim, and two short `knob-ink` pointer marks, the same two lines engraved on the CMF case's dial. The marks rotate to point at the active segment. A warm `glow` rim light catches the knob's upper left.
- **Knob label**: the active mode's icon and short name, always upright, in `knob-ink`.

## Behaviour

- **Turn** moves the highlight one segment per detent, clockwise for a right turn. At either end it jumps across the gap, so the wheel never dead-ends.
- **Press** sinks the knob, flashes the active segment and sends a warm pulse out from the knob, then chooses that mode.
- **Click** a segment to jump straight to it (mouse users, settings).
- **Inside a mode** the ring stays put and only the knob face turns, 24° per detent (`knob-detent`), so the hand and the screen keep agreeing.

## Order, clockwise from the gap

Volume, Brightness, Apps, Mission Control, Desktops, Tabs, Scroll, Undo / Redo, Slides. System levels sit top right, getting around sits along the bottom, editing and presenting sit on the left. Apps lands at about four o'clock so its card fan can open to the right.

## Do and don't

- Do keep the ring dark in both themes; only `ring-well` and the ground change.
- Do keep one short word on the knob ("Mission", not "Mission Control").
- Don't add a tenth segment without shrinking icons; nine at about 35° each is the comfortable limit.
- Don't put text on the ring. Names live on the knob and in the HUD.
