# MissionControl

Mission Control mode: choosing it spreads every window out, as the three-finger swipe up does; turning hops between windows and pressing brings one forward.

## Behaviour

- **Choose Mission Control** on the dial and it opens immediately. The dial folds away; the HUD pill sits at the bottom centre of the screen and stays while Mission Control is open.
- **Turn** moves a selection ring (`card-border-active`, 2px) from window to window in reading order, left to right, then down. The selected window grows 3% and shows its title in a dark pill (`ring` with `icon-active` text) under it.
- **Press** brings that window forward and closes Mission Control.
- **Double press** closes it without changing anything.

## Motion

Windows travel from their stacked desktop positions to the spread layout in 380ms on `ease-spring`, 22ms apart, so the screen opens like a deck being dealt. The desktops strip slides down from the top edge as they land. Closing reverses it with no stagger.

## Build note

macOS has no public API to drive Mission Control's own selection. Opening it is easy (the Mission Control key event), but moving between its windows with the dial may need arrow keys, which Phase 0 should test. The fallback is Dial's own window picker: thumbnails from ScreenCaptureKit, laid out exactly like this preview, with the Accessibility API raising the chosen window.
