# Eagle on Linux

`applications.nix` installs the unofficial [Eagle-Linux](https://github.com/shana0440/Eagle-Linux) port on x86_64 desktop Linux. Run `make home`, then open **Eagle** from the app launcher or run `eagle`. The port ships with an older Electron runtime with its sandbox disabled, and is packaged here with AI search disabled. Eagle still requires a license after the trial.

## Media Preview Server

With a library open in Eagle, run `nix run .#eagle-media-preview` from this repo to install the [Media Preview Server](https://github.com/tuki0918/eagle-media-preview-server) plugin. Then open **Media Preview Server** in Eagle's plugin panel, click **Start**, and open the endpoint shown there.

For access from other devices on a trusted LAN, configure password protection before turning on **Public Network**.
