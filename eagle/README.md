# Eagle on Linux

`applications.nix` installs the unofficial [Eagle-Linux](https://github.com/shana0440/Eagle-Linux) port on x86_64 desktop Linux. Run `make home`, then open **Eagle** from the app launcher or run `eagle`. The port runs without Wine, ships with an older Electron runtime with its sandbox disabled, and is packaged here with AI search disabled. Eagle still requires a license after the trial.

If you used the Wine version, open your existing library in native Eagle using its Linux path (not `Z:\`). The Wine prefix and settings are not migrated. To run the old version instead, close native Eagle and use `nix run .#eagle-wine` from the repo root.
