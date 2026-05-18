# Idol Follower

<video src="preview.mp4" autoplay loop muted playsinline width="100%"></video>

A floating 3D model viewer for macOS. Load any 3D model, image, or GIF and it subtly follows your mouse — always on top, fully transparent, no window chrome.

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
| Right-click drag | Set base orientation (saved) |
| Scroll or pinch | Resize window |
| Drag | Move window |
| ⌘N | New window |
| ⌘W | Close window |
| ⌘Q | Quit |

Window positions, models, and settings are saved and restored on relaunch.

## Per-window settings

Right-click the app menu icon to access each window's submenu:

- **Change Model** — load a new file
- **↔ / ↕** — horizontal and vertical motion sensitivity (−2 to +2, negative inverts direction)
- **Lock Up / Down** — freeze vertical parallax
- **Lock Left / Right** — freeze horizontal parallax
- **Invisible to Mouse** — click-through mode

## Supported formats

**3D models** — USDZ · USDA · USDC · OBJ · DAE · SCN · ABC · PLY

**Images** — PNG · JPG · HEIC · TIFF · BMP · WEBP

**Animated** — GIF
