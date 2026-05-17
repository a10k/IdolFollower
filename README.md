# Idol Follower

A floating 3D model viewer for macOS. Load any 3D file and the model subtly follows your mouse — always on top, no window chrome.

## Requirements

macOS 13 or later

## Build & Run

```bash
./build.sh
open "Idol Follower.app"
```

The first time macOS asks you to confirm, right-click the app and choose **Open**.

## Controls

| Action | What it does |
|--------|--------------|
| Move mouse | Model tilts toward cursor |
| Right-click drag | Rotate base orientation (saved) |
| Scroll or pinch | Resize the window |
| Drag | Move the window |
| ⌘N | New window |
| ⌘O | Load a 3D file into this window |
| ⌘W | Close window |
| ⌘Q | Quit |

Window positions and models are saved and restored on relaunch.

## Supported formats

USDZ · USDA · USDC · OBJ · DAE · SCN · ABC · PLY
