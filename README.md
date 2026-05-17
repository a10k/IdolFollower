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
| ⌘O | Load a new 3D file |
| ⌘Q | Quit |

## Supported formats

USDZ · OBJ · DAE · SCN · ABC · PLY
