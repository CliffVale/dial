# AppFan

Apps mode: a fan of app cards that opens from the Apps segment, so turning the dial moves through apps like flipping cards.

## Behaviour

- Choosing **Apps** keeps the dial on screen. The ring holds on Apps and stops moving; only the knob face turns, one `knob-detent` per app.
- Cards fan out on an arc around the dial's centre, 12° apart. The selected card sits on the axis, at full opacity, in `card-active` with a `card-border-active` edge. Neighbours step down to 62%, 32% and 12% opacity and 95% size, and tilt with the arc.
- A hairline connector in `card-border-active` runs from the lifted Apps segment to the selected card, with an elbow so it clears the ring.
- The list wraps. Order is most recently used first, so a single detent is usually the app you want.
- **Press** opens or switches to the app: the card flashes `segment-active`, then the fan and dial fold back to the menu bar.
- **Double press** closes the fan and returns to the mode wheel without switching.

## Cards

- 208 × 44px, `radius-md`, `card` with `card-border` and `shadow-card`.
- A 26px tile, the app name in `card-title` and its shortcut position in `card-meta`.
- In the real app the tile is the app's own icon from the system. The previews use a letter on `ring`, because they shouldn't redraw anyone's app icon.
