# Wallpapers

All wallpaper dependencies are declared in `wallpaper.nix`: awww, ImageMagick,
Python with NumPy and Pillow, and Qt shader tools (build time). The picker and
transition run in the existing Quickshell configuration.

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

## Pixel-colony transition

Every change (picker or `wallpaper-set`) spreads in as pixel colonies over about
1.8 s: several colonies land at random places and moments and eat through the old
wallpaper along a noise field in crisp 5 px cells. Freshly flipped cells burn
briefly in the new image's most vivid colour, a soft glow rides the front, and
rare sparks jump just ahead of it. Starting from awww's solid startup colour
works the same way.

- `colonies.py` makes the arrival maps: shortest paths over a noise-derived cost
  from the colony seeds, ranked so covered area grows evenly in time. The maps do
  not depend on the wallpaper, so a pool of 8 lives in
  `${XDG_CACHE_HOME:-~/.cache}/wallpaper/colonies/`. The picker fills it when it
  opens; each used map is regenerated in the background so patterns don't repeat.
  An empty pool costs one synchronous map (about 0.25 s).
- `colonies.frag` draws the cells; `WallpaperTransition.qml` hosts it on a layer
  above awww and below windows, covering the full output including the bar's
  reserved strip.
- Hand-over: the layer fades in while the shader still shows exactly the old
  image, awww switches underneath with no transition, the shader ends on exactly
  the new image, and the layer fades out. Each output uses its own old image and
  awww's centred-cover crop, including portrait and fractional-scale outputs.

The picker closes before the colonies start. Rapid `wallpaper-set` calls are
serialized, so awww never changes underneath a running transition. A plain awww
fade is used only if the transition can't run: Quickshell not running, a shader or
asset failure, or a timeout.

Design reference: [diegoMalagrida/pocket-dots](https://github.com/diegoMalagrida/pocket-dots)
("contagio"). This is an independent implementation; no GPL code was copied.

## Commands

```sh
wallpaper-set '/path/to/my wallpaper.png'
wallpaper-library            # JSON catalog; refresh thumbnails
wallpaper-colonies warm      # fill the transition map pool
wallpaper-colonies time      # time one map generation
wallpaper-colonies accent IMG  # the burn colour chosen for an image
wallpaper-check -v           # backend and colony map regression tests
quickshell --path ~/.config/quickshell ipc call wallpaper toggle
quickshell --path ~/.config/quickshell ipc call wallpaper state
```

`wallpaper-set` prints `transition-ready` when the colonies are about to start
(the picker uses it to close); a successful exit means the full hand-over to awww
finished. `WALLPAPER_SHELL` points it at another Quickshell config (isolated
tests); `WALLPAPER_SHADER` overrides the compiled shader path.

## Cache

- Thumbnails: `${XDG_CACHE_HOME:-~/.cache}/wallpaper/thumbnails`. Up to four
  decoders, atomic writes, a refresh lock, and pruning of removed images.
- Colony maps: `${XDG_CACHE_HOME:-~/.cache}/wallpaper/colonies/<version>/`, written
  atomically under per-slot locks. Bump `VERSION` in `colonies.py` when changing
  the map format.

Source images are never modified.

## Verification

- `wallpaper-check`: catalog filtering/sorting, thumbnail reuse, invalidation and
  cleanup, special filenames, awww errors, the ready/done handshake, solid-colour
  starts, renderer abort, map renewal, fade fallback, even area growth, connected
  colonies (not speckle), pool reuse and atomic warm-up, and accent selection.
- Private agent workspace: nested Sway on X11 with its own runtime, cache, and
  awww, plus a stand-in 52 px reserved bar. Covered: solid colour → image, picker →
  colonies, CLI changes, the reserved strip changing with the rest of the screen
  (no early reveal), missing-shell fallback, concurrent switches, and landscape +
  portrait (scale 1.5) outputs. Host wallpapers were not changed by these tests.

Recordings (outside the repository):

- `~/Videos/agent-recordings/wallpaper-colonies.mp4`
- `~/Videos/agent-recordings/wallpaper-colonies-2-outputs.mp4`
