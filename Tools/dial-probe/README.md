# dial-probe

Phase 0 logger. Shows what the CMF Smart Dial actually sends to the Mac.

## Build

```
cd Tools/dial-probe
swift build -c release
```

The binary is `.build/release/dial-probe`.

## Options

| Flag | What it does |
|---|---|
| (none) | logs media-key events (CGEventTap), output device changes and every volume control on the default output |
| `--now-playing` | also becomes the Now Playing app with a silent player and logs MPRemoteCommandCenter commands |
| `--park 0.5` | sets the volume back to 0.5 after every turn, to test the midpoint reset |
| `--verbose` | also logs system-defined events that aren't media keys |

Type a note and press Return to put a `MARK` line in the log. Ctrl-C prints a summary.

## Permission

Grant **Input Monitoring** to your terminal app (System Settings → Privacy & Security → Input Monitoring), then quit and reopen the terminal. Nothing else is needed.

## Test script

Before each run, set the buds as the sound output and set the volume to about 50%. Leave about 1 second between gestures. Before each block, type its label and press Return.

1. turn right 5 clicks slowly (about 1 per second)
2. turn right 5 clicks quickly
3. turn left 5 clicks slowly
4. turn left 5 clicks quickly
5. press once, wait 3 s, press once
6. double press, wait 3 s, double press

Run the script five times:

| Run | Command | Spotify |
|---|---|---|
| A | `.build/release/dial-probe \| tee -i ~/Desktop/probe-A.log` | quit |
| B | `.build/release/dial-probe \| tee -i ~/Desktop/probe-B.log` | playing |
| C | `.build/release/dial-probe --now-playing \| tee -i ~/Desktop/probe-C.log` | quit |
| D | `.build/release/dial-probe --now-playing \| tee -i ~/Desktop/probe-D.log` | playing, started **before** the probe |
| E | `.build/release/dial-probe --park 0.5 \| tee -i ~/Desktop/probe-E.log` | quit; turns only: right 10 quickly, left 10 quickly |
