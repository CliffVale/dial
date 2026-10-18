# ModeHUD

The small pill under the menu bar item that confirms what each turn just did, then gets out of the way.

## Three shapes, one pill

- **Level** (Volume, Brightness): icon, label, a 72px meter in `hairline` filled with `ink`, and the number in `hud-value`.
- **Step** (Desktops, Tabs, Slides, Undo / Redo, Scroll): icon, label and a position or count: `3 / 8`, `Undo ×2`, `↓ 6 lines`. No meter.
- **List** (Apps, Mission Control): icon, label and the item under the cursor. Apps also opens the card fan; Mission Control shows the window position.

A press inside a mode shows the press action's name in the value slot for one linger cycle ("Mute", "New tab").

## Rules

- 34px tall, `radius-pill`, `card` with a `card-border` hairline and `shadow-card`.
- It hangs from the menu bar item, centred under the glyph, `space-3` below the bar.
- Every turn restarts the 1.2s linger (`hud-linger`). The value nudges up 2px on change so a turn you can't see on screen (volume) still registers.
- Never more than one HUD. A new mode replaces the old one in place; it doesn't stack.
