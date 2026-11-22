# Wallpaper

Put JPG, PNG, or WebP images, or MP4, WebM, MKV, or MOV videos in
`~/Pictures/Wallpapers`, then press `Super+Shift+W` to pick one, or run:

```sh
wallpaper-set '/path/to/image.png'
```

The new wallpaper spreads over the old one in an animated transition. Files
are never modified.

A video wallpaper loops without sound and plays while it spreads in. The lock
screen, overview, and login screen show its first frame.

The transition is inspired by pocket-dots' "contagio" transition and
implemented independently.
