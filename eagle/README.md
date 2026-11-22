# Eagle on Linux

`applications.nix` installs the unofficial [Eagle-Linux](https://github.com/shana0440/Eagle-Linux) port on x86_64 desktop Linux. Run `make home`, then open **Eagle** from the app launcher or run `eagle`. The port ships with an older Electron runtime with its sandbox disabled, and is packaged here with AI search disabled. Eagle still requires a license after the trial.

## Media Preview Server

After `make home`, open a library in Eagle, run `eagle-media-preview-install`, and confirm the installation. To run the installer without switching Home Manager, use `nix run .#eagle-media-preview` from this repo instead.

In Eagle's plugin panel, select **Service → Media Preview Server**, turn on the switch beside **Server Status**, and open the endpoint shown there. See the [plugin guide](https://github.com/tuki0918/eagle-media-preview-server) for settings.

For access from other devices on a trusted LAN, configure password protection before turning on **Public Network**.
