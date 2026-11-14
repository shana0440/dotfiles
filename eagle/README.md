# Eagle on Linux (experimental)

Runs the Windows version of Eagle under Wine. Enabled by `applications.nix` on
x86_64 desktop Linux. Eagle is proprietary and needs a license after its trial.

After `make home`, open **Eagle** from the app launcher (or run `eagle`). The
first launch installs .NET, fonts, and Eagle; it takes several minutes and
needs internet access.

- Linux files appear as `Z:\` in Eagle's file dialogs. Eagle is not sandboxed.
- **Open in Explorer** (`Ctrl+Enter`) opens the folder in your Linux file manager.
- Close Eagle before `make home`, and restart it afterwards.
- Browser integration, plugins, and video/PSD/RAW previews may not work.
