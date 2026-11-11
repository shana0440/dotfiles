# Wallpapers

All wallpaper command dependencies are declared in `wallpaper.nix`:
Python, ImageMagick, and awww. The picker uses the existing Quickshell installation.

## Usage

Put JPG/JPEG, PNG, or WebP images in `~/Pictures/Wallpapers` (capital W).
Subdirectories are not scanned. The directory is not created or populated automatically.

- **Super + W**: toggle the picker on the focused monitor.
- **Left / Right**, mouse wheel, or click a card: select a wallpaper.
- **Enter** or double-click a card: apply to all monitors with a short fade.
- **Escape** or click outside: cancel without changing the wallpaper.

Cards use parallelogram frames with clipped, upright artwork: only the frame
is sheared; an inverse transform keeps the image itself undistorted.

Opening refreshes thumbnails asynchronously and selects the wallpaper currently
shown by awww. Invalid images are skipped with a warning; application errors keep
the picker open. The picker does not change theme colours or run AI segmentation.

Commands:

```sh
wallpaper-set '/path/to/my wallpaper.png'
wallpaper-library  # JSON catalog; refreshes thumbnails
wallpaper-check -v # backend regression tests
quickshell --path ~/.config/quickshell ipc call wallpaper toggle
quickshell --path ~/.config/quickshell ipc call wallpaper state
```

`WALLPAPER_DIR` overrides the source directory for the catalog. Thumbnails live in
`${XDG_CACHE_HOME:-~/.cache}/wallpaper/thumbnails`, use content-versioned filenames,
and are written atomically. Up to four images are decoded at once; a file's path,
size, and modification time determine whether it needs regeneration. A refresh
lock prevents overlapping cache cleanup. Removed and replaced images are pruned.

`wallpaper-set` is the future integration point for outline transitions.

## Verification

`wallpaper-check` covers image filtering, sorting, thumbnail reuse, invalidation,
orphan cleanup, interrupted conversion cleanup, special filenames, and daemon
failure propagation. It uses temporary files and does not change the wallpaper.

UI verification uses an agent workspace's private X11 desktop with nested Sway
(the native Hyprland workspace prerequisites are unavailable on this host), a
separate awww daemon, runtime directory, cache, and copied sample images. Verified:

- Coverflow rendering and keyboard navigation.
- Enter applies the selected image, including paths containing spaces and `#`.
- Reopening selects the current wallpaper.
- Escape cancels browsing without applying the selection.
- A daemon failure keeps the picker open with an error.
- Removing all source images produces the empty-library state.

The recording is stored outside the repository at
`~/Videos/agent-recordings/wallpaper-picker.mp4`.
