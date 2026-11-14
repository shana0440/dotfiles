# File manager

`file-manager.nix` exports two modules:

- `nixos`: Tumbler thumbnail service and AppImage binfmt. Apply with `make nixos`.
- `homeManager`: Thunar, File Roller, and the [AppImage runner](appimage/README.md),
  set as the folder, archive, and AppImage handlers. Apply with `make home`.

## Thumbnails

Thunar does not render previews itself; it asks Tumbler over D-Bus
(`org.freedesktop.thumbnails.Thumbnailer1`). Tumbler starts on demand and
writes PNGs to `~/.cache/thumbnails/`, which Thunar reuses on later visits.
It covers images (including WebP, HEIC/AVIF, JXL, RAW), videos (ffmpeg), PDF,
fonts, EPUB, and ODF.

Tumbler is a NixOS service, not a Home Manager package: the session bus is
dbus-broker, which activates it through its `tumblerd.service` systemd user
unit, and only `services.tumbler.enable` installs that unit.

After `make nixos`, run `thunar -q` so the background Thunar reconnects.
Clearing `~/.cache/thumbnails/` is always safe; it is regenerated.

Verified in an agent workspace on a private bus: icons before, thumbnails for
MP4, WebM, WebP, JPEG, and PNG after.
