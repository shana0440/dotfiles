# Eagle on Linux

`applications.nix` installs the unofficial [Eagle-Linux](https://github.com/shana0440/Eagle-Linux) port on x86_64 desktop Linux. Run `make home`, then open **Eagle** from the app launcher or run `eagle`. The port runs without Wine, ships with an older Electron runtime with its sandbox disabled, and is packaged here with AI search disabled. Eagle still requires a license after the trial.

Open an existing library by its Linux path. To run the Windows version under Wine instead, close native Eagle and run `nix run .#eagle-wine` from the repo root.
