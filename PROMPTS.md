# Prompts for Claude Code

## Before you start

1. Unzip this folder somewhere like `~/Projects/Dial`. Keep `CLAUDE.md` at the root, next to `design/`. Claude Code reads `CLAUDE.md` automatically.
2. Install the tools: `brew install xcodegen`, plus Xcode with its command line tools.
3. In the Nothing X app, set the Smart Dial gestures:
   - single press: play/pause
   - double press: next track
   - rotate: volume (the default)
4. Connect the buds to the Mac and make them the sound output.
5. Open a terminal in the folder and run `claude`.

Paste one prompt per phase. Wait for each phase's summary, test what it asks, and report back before moving on.

## Phase 0: Probe

```
Read CLAUDE.md and design/DESIGN.md. We're starting Phase 0 only.

Build Tools/dial-probe as described in CLAUDE.md. Then tell me:
- exactly how to build and run it
- which permission to grant Terminal
- a short test script to follow with the buds

Example: "turn right 5 clicks slowly, 5 quickly, turn left 5, press once, double press once, then repeat with Spotify playing".

Don't start Phase 1. When I paste the logs back, write docs/phase0-findings.md and recommend the capture path.
```

Then run the test and paste the log output back in.

## Phase 1: Input core and menu bar

```
Phase 0 findings are in docs/phase0-findings.md. Start Phase 1 from CLAUDE.md.

Use the capture path we chose. Include SimulatedInput with the global hotkeys from CLAUDE.md, and a debug log window.

Stop when done. Tell me what to test with the real dial and with the hotkeys.
```

## Phase 2: The dial

```
Start Phase 2. Copy design/DialTokens.swift into the app and build RingShape, KnobView and DialView exactly to design/DESIGN.md, in a non-activating panel under the status item.

Look at design/reference/screenshots/dial-rest-dark.png, dial-mission-selected-dark.png and menubar-dial-open-dark.png (and the light versions) before you start. Compare your SwiftUI previews against them when you're done.

Implement every motion row in DESIGN.md: summon, detent, fast spin, press, choose, idle dismiss and Reduce Motion. Flag anything you had to guess.
```

## Phase 3: Modes, HUD and menu bar label

```
Start Phase 3. Implement all nine modes from the CLAUDE.md table, the Accessibility permission flow, the HUD panel and the menu bar mode label.

Match design/reference/screenshots/hud-*.png and menubar-in-mode-*.png.

Tell me how to test each mode, and which ones need a system setting turned on (like the Desktops shortcuts).
```

## Phase 4: Apps fan and Mission Control

```
Start Phase 4. Build the app fan per design/DESIGN.md and match appfan-*.png.

For Mission Control, first add a test where I open it from the dial and turn. Try arrow keys inside native Mission Control and log whether the selection moves. Only build the fallback window picker (match mission-spread-*.png) if the native route doesn't work.
```

## Phase 5: Settings and polish

```
Start Phase 5 from CLAUDE.md. Build:
- a Settings window: reorder modes, turn modes on or off, choose press actions, in the style of design/brand-book.md
- launch at login
- Reduce Motion support
- first-run onboarding that walks through the Nothing X gesture setup and the permissions

Then do a pass for anything in DESIGN.md that's still missing.
```

## Useful one-liners

- **Visual check:** "Render DialView in dark and light at 2x to PNGs and compare them with the reference screenshots. List the differences."
- **Motion check:** "Slow every DialMotion animation down 5x behind a debug flag so I can compare them with the HTML reference."
- **After a confusing bug:** "Add timestamped logging to the input pipeline from raw event to DialEvent to state change. Tell me what to do with the dial, and I'll paste the log."
