# Wallpaper

Home Manager module (`wallpaper.nix`) that runs [awww](https://github.com/LGFae/awww)
and installs commands for listing and switching wallpapers. Changes spread in as
pixel colonies drawn by the Quickshell `WallpaperTransition` component.
All dependencies are declared in `wallpaper.nix`.

## Usage

Put JPG/JPEG, PNG, or WebP images in `~/Pictures/Wallpapers` (not scanned
recursively), then:

```sh
wallpaper-set '/path/to/image.png'   # apply to all monitors
wallpaper-library                    # list wallpapers as JSON, refresh thumbnails
wallpaper-colonies warm              # pre-generate transition maps
wallpaper-check -v                   # run the tests
```

`wallpaper-set` exits once the change is complete. If Quickshell isn't running or
the transition fails, it falls back to a plain awww fade.

Changes may overlap: choosing another wallpaper while a transition runs (the
Quickshell picker, Super+Shift+W, stays usable) starts its transition at once,
spreading over whatever is on screen.

## How the transition works

Colonies land at random places and times and spread over the old wallpaper in
small square cells, following a precomputed arrival map. Each change is its own
transparent layer above awww, newest on top; once a layer has covered the
screen, awww is switched to its image underneath and the layer is removed. `colonies.py` generates
the maps, and `colonies.frag` renders them. Maps don't depend on the image, so a
small pool is kept and each map is replaced after use.

## Files and settings

- Thumbnails: `${XDG_CACHE_HOME:-~/.cache}/wallpaper/thumbnails`
- Transition maps: `${XDG_CACHE_HOME:-~/.cache}/wallpaper/colonies`
- `WALLPAPER_DIR` overrides the wallpaper folder.
- `WALLPAPER_SHELL` / `WALLPAPER_SHADER` override the Quickshell config and
  shader paths (useful for testing in isolation).

Source images are never modified.

Transition design inspired by [pocket-dots](https://github.com/diegoMalagrida/pocket-dots);
this is an independent implementation.
