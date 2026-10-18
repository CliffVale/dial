# Dial

Dial is a macOS menu bar app that turns the Smart Dial on a CMF Buds Pro 2 earbuds case into a control surface for the Mac.

- **Double press** opens a radial wheel of nine modes under the menu bar item.
- **Turn** to pick a mode; **press** to choose it.
- From then on, every turn drives that mode (volume, brightness, tabs, desktops and so on) until the next double press.

The owner is Art, a product designer. He reviews UI against the design references, so visual accuracy matters as much as working input.

## Read these first

- `design/DESIGN.md`: the build spec for every piece of UI. Start here for anything visual.
- `design/DialTokens.swift`: colours, geometry, type, shadows and motion, generated from `design/tokens.json`. Copy it into the app target and use it everywhere; never hard-code a value that has a token.
- `design/reference/screenshots/`: the target look for every state, dark and light. When you build a view, compare a SwiftUI preview or a screenshot against the matching PNG.
- `design/reference/*.html`: interactive references for motion. Art can open them in a browser; treat them as the spec for timing and feel, not as code to port.
- `design/motion.md`, `design/brand-book.md`, `design/components/*.md`: the detail behind DESIGN.md.

## How the hardware talks to the Mac

The dial on the case doesn't talk to the Mac. It talks to the earbuds, and the earbuds send standard Bluetooth headphone commands. With the gestures set in the Nothing X app, the expected mapping is:

| Physical action | Arrives on the Mac as | Dial uses it as |
|---|---|---|
| Rotate | a change in the buds' output volume (absolute volume) | one detent left or right, by the sign of the change |
| Single press | play/pause | press |
| Double press | next track | double press (open/close the wheel) |

This mapping is **unverified** until Phase 0 proves it. Don't build Phase 1 on assumptions; build it on what the probe logs show.

## Turning volume changes into a rotary encoder

- **Listening.** Watch the buds' output device with CoreAudio property listeners (the virtual main volume, plus the main element and channels 1 and 2 if needed). Only react when the default output device is the buds, matched by name or by `kAudioDeviceTransportTypeBluetooth`.
- **Direction.** Use the sign of each change as one detent. Don't trust its size; absolute volume is often quantised to about 16 steps.
- **In every mode except Volume**, set the volume back to a fixed midpoint after each detent, so the dial never hits 0 or 100% and stops reporting. Our own reset fires the listener too, so ignore changes that land on the value we just wrote.
- **In Volume mode**, let the change through and only show the HUD.
- **Detent rate.** Record a timestamp per detent so the UI can switch to fast-spin animation when detents arrive under 70ms apart.

## Tech decisions

- Swift 5.10+, SwiftUI for views, AppKit for the status item and panels. Target macOS 14 or later.
- Generate the Xcode project with XcodeGen from `project.yml`. Don't hand-edit `.xcodeproj` files.
- The app is a menu bar app (`LSUIElement = YES`): no Dock icon and no main window, except Settings.
- Bundle id `com.art.dial` (a placeholder; ask Art before shipping).
- No App Sandbox. The app posts synthetic events and uses the Accessibility API, which the sandbox blocks. Distribution is direct, not the App Store.
- **Panels.** The dial and the HUD each live in a borderless, non-activating `NSPanel` at status-bar level, `canJoinAllSpaces`, with a transparent background. They must never take focus away from the app being controlled.
- **State.** One `@Observable` app model owns the state machine; views only read it.
- **Dependencies.** None, unless Art agrees. Use system frameworks only: CoreAudio, CoreGraphics events, MediaPlayer, ApplicationServices (AX), ScreenCaptureKit.

## Architecture

```
Dial/
  project.yml
  Dial/
    App/        DialApp.swift, AppDelegate.swift, StatusItemController.swift
    Input/      DialEvent.swift              enum: turn(Int), press, doublePress
                InputSource.swift            protocol, so real and simulated input are interchangeable
                VolumeEncoder.swift          CoreAudio listener + midpoint reset
                MediaKeyTap.swift            CGEventTap on system-defined events, if Phase 0 shows they arrive there
                RemoteCommandSource.swift    MPRemoteCommandCenter, only if Phase 0 says it's needed
                SimulatedInput.swift         global hotkeys for development without the buds
    State/      DialModel.swift              @Observable: rest / picking / inMode(Mode), selection, angles
                Settings.swift               order, enabled modes, press actions, persisted
    Modes/      Mode.swift                   protocol: id, label, shortLabel, kind, turn(_:), press()
                VolumeMode.swift … SlidesMode.swift   one file per mode
    Actions/    KeyEmitter.swift             CGEvent key presses with modifiers
                ScrollEmitter.swift          pixel or line scroll events
                SystemControls.swift         volume, brightness, mute
                AppSwitcher.swift            running apps by recent use, activation
                WindowControl.swift          AX window listing and raising
    UI/         DialTokens.swift             copied from design/
                DialPanel.swift, DialView.swift, KnobView.swift, RingShape.swift
                HUDPanel.swift, HUDView.swift
                AppFanView.swift, WindowPickerView.swift
                SettingsView.swift
  Tools/
    dial-probe/  Swift package, the Phase 0 logger
```

## How each mode acts

| Mode | Turn | Press | Notes |
|---|---|---|---|
| Volume | pass-through | toggle mute | |
| Brightness | brightness down/up keys | toggle Night Shift (or nothing at first) | Post `NX_KEYTYPE_BRIGHTNESS_DOWN`/`UP` as system-defined events. External displays may ignore them; note it, don't fight it. |
| Apps | move through the fan | activate the app | Order apps by most recent use, from `NSWorkspace` activation notifications. |
| Mission Control | open, then move the selection | raise the window, close | Open with the Mission Control app or key. Try arrow keys inside it first; fall back to Dial's own window picker (ScreenCaptureKit thumbnails + AX raise). |
| Desktops | ⌃← / ⌃→ | show desktop | Needs "Move left/right a space" shortcuts enabled in Keyboard Shortcuts; detect and tell the user if they're off. |
| Tabs | ⌃⇧⇥ / ⌃⇥ | ⌘T | |
| Scroll | 3-line scroll per detent | toggle vertical/horizontal | |
| Undo / Redo | ⌘Z / ⇧⌘Z | ⌘S | |
| Slides | ← / → | start or end the show | |

## Permissions

- **Accessibility**: posting key and scroll events, AX window control. Prompt with `AXIsProcessTrustedWithOptions`.
- **Input Monitoring**: only if the event tap is the chosen press path.
- **Screen Recording**: only for the Mission Control fallback thumbnails, and only when that mode is first used.

macOS ties these grants to the code signature. When a rebuild stops working after permissions were granted, reset them, then re-grant:

```
tccutil reset Accessibility com.art.dial
```

## Working with Art

- Art runs the app with the real buds and pastes logs back to you. You can't press the dial, so write clear, timestamped logs for anything input-related, and say exactly what he should do (for example "turn right 5 clicks slowly, then 5 quickly") and what you expect to see.
- `SimulatedInput` must exist from Phase 1, so UI work never waits on hardware. Suggested global hotkeys: ⌃⌥← and ⌃⌥→ to turn, ⌃⌥Space to press, ⌃⌥D to double press.
- Build from the command line with `xcodegen && xcodebuild -scheme Dial -configuration Debug build`, and say how to launch the result.
- Commit at the end of each phase, with the phase in the message.
- When a visual choice isn't covered by `design/`, pick the option closest to the references, then flag it in your summary for Art to review. Don't invent new colours or curves.

## Phases

Finish each phase's checks before starting the next. Stop at the end of every phase and summarise what changed and what Art should test.

**Phase 0: Probe.** Build `Tools/dial-probe`, a command-line Swift package that logs, with millisecond timestamps:
- CGEventTap system-defined media key events, decoded to key type, down/up and repeat;
- default output device changes, and volume changes on that device (name, transport type, scalar value);
- with `--now-playing`, the MPRemoteCommandCenter commands received while registered as Now Playing using a silent player.

Done when Art can run it with the buds and the log shows distinct, repeatable signals for turn left, turn right, press and double press, both with Spotify playing and without. Write the findings into `docs/phase0-findings.md` and recommend the capture path.

**Phase 1: Input core and menu bar.**
- The app shell: status item, `DialEvent` stream, `VolumeEncoder` with midpoint reset, the chosen press path, `SimulatedInput`, and the `DialModel` state machine (rest, picking, inMode).
- A debug log window behind a menu item.

Done when real dial input and simulated hotkeys both drive the state machine correctly, and the volume stays parked at the midpoint outside Volume mode.

**Phase 2: The dial.** `RingShape`, `KnobView` and `DialView`, built to `design/DESIGN.md` in a non-activating panel under the status item, with summon, detent, fast-spin, press, choose and idle-dismiss motion.

Done when SwiftUI previews and screenshots match `reference/screenshots/dial-*` and `menubar-dial-open-*` in both appearances, and the motion matches `reference/Dial.html` side by side.

**Phase 3: Modes.** Every mode in the table above. Includes the Accessibility prompt flow, plus the HUD panel and menu bar label from DESIGN.md.

Done when each mode works in Safari, Finder, Keynote or Google Slides, and one code editor, and the HUD matches `hud-*` and `menubar-in-mode-*`.

**Phase 4: Apps fan and Mission Control.** The fan per DESIGN.md. Mission Control native first, then the fallback picker if needed.

Done when they match `appfan-*` and `mission-*`.

**Phase 5: Settings and polish.**
- A Settings window: reorder modes, turn modes on or off, choose press actions.
- Launch at login (`SMAppService`), Reduce Motion support, and first-run onboarding that explains the Nothing X gesture setup and grants permissions.

## Don'ts

- Don't put text on the ring; names belong on the knob and in the HUD.
- Don't use the `glow` colour for anything but the knob rim light, the press pulse and the tether dot.
- Don't set angles modulo 360; accumulate them (see DESIGN.md).
- Don't let either panel activate or become key.
- Don't add third-party packages without asking.
