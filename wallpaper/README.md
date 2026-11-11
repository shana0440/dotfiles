# Wallpapers

All wallpaper dependencies are declared in `wallpaper.nix`: awww, ImageMagick,
and Python. The picker uses the existing Quickshell installation.

## Picker

Put JPG/JPEG, PNG, or WebP images in `~/Pictures/Wallpapers` (capital W).
Subdirectories are not scanned. The directory is not populated automatically.

- **Super + Shift + W**: toggle the picker on the focused monitor.
- **Left / Right**, mouse wheel, or click a card: select a wallpaper.
- **Enter** or double-click a card: apply to all monitors.
- **Escape** or click outside: cancel without changing the wallpaper.

Cards have parallelogram frames with clipped, upright artwork. Opening refreshes
thumbnails asynchronously and centers the current wallpaper before fading in,
without scrolling from the first image. Invalid images are skipped with a warning;
application errors keep/reopen the picker with an error. Theme colours are unchanged.

## Commands

```sh
wallpaper-set '/path/to/my wallpaper.png'
wallpaper-library                      # JSON catalog; refresh thumbnails
wallpaper-check -v                      # library/switching regression tests
quickshell --path ~/.config/quickshell ipc call wallpaper toggle
quickshell --path ~/.config/quickshell ipc call wallpaper state
```

`wallpaper-set` remains the switching entry point. For a prepared transition it
prints `transition-ready` before starting, allowing the picker to close; successful
exit still means the complete awww handoff finished. `WALLPAPER_SHELL` overrides the
compiled shader path for renderer diagnostics.
