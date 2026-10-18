# MenuBarDrop

The dial's home: a menu bar item that shows the current mode and drops the dial straight down from under itself.

## The loop

1. **Rest.** The menu bar item shows the ring glyph and the current mode's name (`hud-label`). Turning drives that mode; the HUD pill appears under the item and fades 1.2s after the last turn (`hud-linger`).
2. **Double press** (the buds send it as "next track"). The item gets its open highlight (`card-active`) and the dial drops from it: the gap in the ring sits directly under the glyph, as if the dial hung from it.
3. **Turn** to move between modes; **press** to choose. The knob sinks, the segment flashes, and the dial folds back up into the item it came from.
4. The menu bar label swaps to the new mode and the HUD shows its current value, so the first turn has context.
5. No input for 4s (`idle-dismiss`) closes the dial without changing the mode. A second double press also closes it.

## Placement

- Horizontally, the dial's centre is the glyph's centre. Near the screen's right edge it may slide left, but the tether dot stays under the glyph.
- Vertically, the ring's top edge sits `space-4` below the menu bar, so the menu bar's own shadow never touches it.
- On notched MacBooks the item can sit just right of the notch; nothing else changes.

## In the real app

The dial and HUD are borderless, non-activating panels at the status-bar window level, so they never steal focus from the app you're controlling. The menu bar item is a status item; clicking it opens the dial as well, for mouse users and for testing.
