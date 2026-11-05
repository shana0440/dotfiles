# Nexon Launcher on Linux (experimental)

Runs the official Windows Nexon Launcher with Wine 11 in a private prefix
(`~/.local/share/nexon/wine`). It is enabled by `applications.nix` on x86_64
Linux. Run `nexon-launcher` or choose **Nexon Launcher** in the app launcher
after `make home`.

The first launch creates the prefix, installs core fonts, downloads the current
installer from Nexon and installs it. The launcher's embedded Chromium is
started with `--no-sandbox --disable-gpu`, which it needs under Wine.
