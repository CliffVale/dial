# Phase 0 findings

Probe runs on 2026-10-18 with CMF Buds Pro 2 (`"CMF Buds Pro 2"`, transport `'blue'`) on macOS 26.6. Nothing X gestures: press = play/pause, double press = next track, rotate = volume. Logs: `~/Desktop/probe-A.log` … `probe-E.log`.

| Run | Probe | Playing | Turns | Press | Double press |
|---|---|---|---|---|---|
| A | plain | nothing | volume steps | nothing | nothing |
| B | plain | Spotify | volume steps | nothing (went to Spotify) | nothing (went to Spotify) |
| C | `--now-playing` | nothing | volume steps | `pause`, then `play` | `nextTrack` |
| D | `--now-playing` | Spotify, started first | volume steps | `pause`, then `play` | `nextTrack` |
| E | `--park 0.5` | nothing | volume steps, parked each time | – | – |

The case lid has to be **closed** for the dial to send anything. With the lid open, nothing arrived.

## Turn

- Every click arrives as a change in the buds' **virtual main volume** (`kAudioHardwareServiceDeviceProperty_VirtualMainVolume`, output scope). Right is up and left is down, with no exceptions in any run.
- Channels 1 and 2 follow within about 5 ms. The device has no main-element volume.
- **Steps are 1/16** (absolute volume 0–127 in steps of 7–8): 0.3150, 0.3780, 0.4409, 0.5039, 0.5591, 0.6220 … 1.0000. One click moves the volume one step (Δ ≈ 0.055–0.063).
- **At 0% or 100% the direction is lost.** Past 100%, each click still fires the listener (`NOTIFY, value unchanged`), but there's no sign to read. Parking is required.
- **Parking works (run E).** After each click the probe wrote 0.5000. The next click read 0.5591 (right) or 0.4409 (left), every time, for 14 changes. The dial never stalled.
- **Our own write echoes back:** 8 notifications per write, all landing on 0.5000, 10–35 ms after the write. The probe's filter caught all of them: ignore anything within 400 ms of a write that's within ±0.032 of the value written. No real click was ever filtered out.
- **The volume never changes without a click.** Nothing appeared during the press blocks, apart from one stray DOWN in run C at 17:59:07, which was most likely an accidental touch.

### Fast turns lose clicks

| Run | Asked for | Changes seen | Shortest gap |
|---|---|---|---|
| A, left fast (not parked) | 5 | 3 (one was a double step, Δ0.118) | 1490 ms |
| B, right/left fast | 5 + 5 | 2 + 2 (right hit 100%) | 1295 ms |
| D, right fast | 5 | 3 | 490 ms |
| E, right fast (parked) | 10 | 7 | 381 ms |
| E, left fast (parked) | 10 | 7 | 321 ms |
| C, left fast | 5 | 3 | 271 ms |

The buds rate-limit volume reports. Changes never came closer than **271 ms** apart. Quick clicks are either dropped or, when not parked, merged into a two-step change.

What this means:
- **Fast spin under 70 ms will never trigger.** We need a threshold of roughly 400–600 ms, or to drop fast spin. This is a design decision for Art.
- **When not parked (Volume mode), count steps,** `round(|Δ| / 0.0625)`, rather than treating every change as one click. When parked, every change is one step.
- **Expect up to about 0.3–0.5 s between a click and the Mac seeing it.** This comes from the hardware, and no code on the Mac can shorten it.

## Press and double press

- **No media-key events in any run.** The CGEventTap saw nothing for any gesture, with or without Spotify. Bluetooth headphone buttons don't go through the HID system-defined event stream.
- **They arrive only through MPRemoteCommandCenter, and only at the Now Playing app.** Without `--now-playing` (A, B) they went to whatever app was playing and the probe saw nothing.
- With `--now-playing`, both with nothing playing (C) and with Spotify playing (D):
  - single press → `pause`, the next press → `play`. They alternate with our playback state; we never received `togglePlayPause`.
  - double press → `nextTrack`, every time.
  - No stray commands.

## Recommended capture path

| Signal | Source | Dial event |
|---|---|---|
| Turn | `VolumeEncoder`: CoreAudio listener on the virtual main volume of the default output, only when it's Bluetooth and named "CMF Buds Pro 2". Re-attach when the default output changes (run A showed the buds dropping out and returning with a new device id). | `turn(±steps)` |
| Press | `RemoteCommandSource`: MPRemoteCommandCenter, registered as Now Playing with a silent `AVAudioEngine` source node. `play`, `pause` and `togglePlayPause` all count. | `press` |
| Double press | same, `nextTrack` | `doublePress` |

- **Parking:** park at 0.5 in every mode except Volume, using the echo filter above.
- **Drop `MediaKeyTap`.** It receives nothing, so Dial doesn't need Input Monitoring.
- **Fast spin:** the CLAUDE.md threshold of 70 ms needs changing; see above.

## Risks to handle in Phase 1

1. **Who owns Now Playing.** If another app starts playing *after* Dial registers, it may take the press and double press. Run D only tested Spotify starting first. Dial needs to win Now Playing back, at least whenever it publishes state. Test F below checks this.
2. **Presses are taken from the media player.** While Dial is Now Playing, the dial press no longer pauses Spotify or YouTube. In Volume mode we may want to pass play/pause on to the media app. This is a product decision for Art.
3. **Silent playback keeps the Bluetooth audio stream open,** which may cost battery. It also adds a `CADefaultDeviceAggregate` device to the device list, which the encoder must ignore.
4. **The default output can fall back to the MacBook speakers** when the buds disconnect. The encoder must stop reacting, and never park the speakers' volume.

## Still to test (run F, optional before Phase 1)

```
.build/release/dial-probe --now-playing | tee -i ~/Desktop/probe-F.log
```
Start the probe with nothing playing. Then press play in Spotify with the mouse, wait 5 s, and press and double press on the dial. If no `[command]` lines appear, Spotify has taken Now Playing, and risk 1 needs a fix in Phase 1.
