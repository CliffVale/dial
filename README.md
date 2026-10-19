# Dial

A macOS menu bar app that turns the Smart Dial on a CMF Buds Pro 2 case into a control surface for the Mac.

- **Double press** the dial: a wheel of nine modes drops from the menu bar.
- **Turn** to pick a mode, **press** to choose it.
- From then on every turn drives that mode (volume, brightness, apps, Mission Control, desktops, tabs, scroll, undo/redo, slides) until the next double press.

Requires macOS 14 or later, on Apple silicon or Intel.

## Install

1. Open `Dial-1.0.dmg` and drag **Dial** into **Applications**.
2. Open Dial from Applications. On another Mac, see [Opening on other Macs](#opening-on-other-macs) first.
3. Follow the setup guide that opens on first launch:
   - **Nothing X:** in the Nothing X app, set the Smart Dial's gestures to press → Play/Pause, double press → Next track, rotate → Volume.
   - **Sound output:** connect the buds and choose them as the output. Keep the case lid **closed**; the dial only sends with the lid shut.
   - **Accessibility:** turn on Dial in System Settings → Privacy & Security → Accessibility. Dial uses it to press keys, scroll and bring windows forward for you.
   - **Launch at login**, if you want it.

Click the menu bar item to open the wheel with the mouse. Right-click (or Control-click) it for Settings, the setup guide, About and Quit.

## Settings

- **Modes:** drag to reorder the ring. Turn modes off to skip them; they stay on the ring, dimmed.
- **Press action per mode:** for example, Volume can play/pause your music or mute.
- **Open Dial when you log in.**
- **Testing tools:** ⌃⌥←/→ turn, ⌃⌥Space presses and ⌃⌥D double presses without the buds, plus a debug log. Off by default.

Desktops mode needs "Move left a space" and "Move right a space" turned on in System Settings → Keyboard → Keyboard Shortcuts → Mission Control (they're on by default).

## Opening on other Macs

This build is signed with a local certificate, not an Apple Developer ID, so on any other Mac macOS will say it can't check the app. To open it anyway, Control-click Dial in Applications, choose **Open**, then **Open** again. Or remove the download flag:

```
xattr -dr com.apple.quarantine /Applications/Dial.app
```

To ship without that step, sign with Developer ID and notarise. See [Releasing](#releasing).

If Accessibility stops working after installing a new build, remove Dial from the Accessibility list and add it again, or run:

```
tccutil reset Accessibility com.art.dial
```

## Building from source

Needs Xcode and XcodeGen (`brew install xcodegen`).

```
xcodegen
xcodebuild -scheme Dial -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Dial.app
```

The Xcode project is generated from `project.yml`; don't edit `Dial.xcodeproj` by hand. The design spec is in `design/`, and the hardware findings are in `docs/phase0-findings.md`.

## Releasing

```
Scripts/release.sh
```

This builds a universal Release (hardened runtime), checks the signature and writes `dist/Dial-<version>.dmg`. It signs with the local "Doey Local" certificate by default.

With an Apple Developer account, install your Developer ID Application certificate and save notary credentials once:

```
xcrun notarytool store-credentials dial --apple-id you@example.com --team-id TEAMID
```

Then:

```
DIAL_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" DIAL_NOTARY_PROFILE=dial Scripts/release.sh
```

That notarises and staples both the app and the DMG, so they open anywhere without a warning.

The version lives in `project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`). The app icon is rendered from the dial itself:

```
build/Build/Products/Debug/Dial.app/Contents/MacOS/Dial --app-icon Dial/Assets.xcassets/AppIcon.appiconset/icon-1024.png
```

Then scale the smaller sizes from it with `sips`.
