{
  nixos = { pkgs, ... }: {
    nixpkgs.config.allowUnfree = true;

    programs.steam.enable = true;

    services.avahi = {
      enable = true;
      publish.enable = true;
      publish.userServices = true;
      openFirewall = true;
    };
    networking.firewall.allowedTCPPorts = [ 7000 7001 7100 ];
    networking.firewall.allowedUDPPorts = [ 6000 6001 7011 ];
  };

  homeManager = { inputs, lib, pkgs, zen-browser, ... }:
    let
      applications = with pkgs; [
        brave
        discord
        bitwarden-desktop
        telegram-desktop
        signalInTray
        remmina
        uxplay
        zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta
        (pkgs.anki.withAddons [
          (pkgs.ankiAddons.anki-connect.withConfig {
            config = {
              webBindAddress = "127.0.0.1";
              webBindPort = 8765;
              webCorsOriginList = [ "http://localhost" ];
            };
          })
        ])
      ] ++ lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
        inputs.self.packages.x86_64-linux.eagle
        (import ./nexon/package.nix { inherit pkgs; })
      ];
      supported = pkg: lib.meta.availableOn pkgs.stdenv.hostPlatform pkg;

      signalInTray = pkgs.symlinkJoin {
        name = "signal-desktop-in-tray";
        paths = [ pkgs.signal-desktop ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = "wrapProgram $out/bin/signal-desktop --add-flags --use-tray-icon";
        inherit (pkgs.signal-desktop) meta;
      };

      spotifyInTray = pkgs.writeShellApplication {
        name = "spotify-in-tray";
        runtimeInputs = [ pkgs.gnused pkgs.gnugrep pkgs.systemd ];
        text = ''
          for prefs in "$HOME"/.config/spotify/Users/*/prefs; do
            [ -f "$prefs" ] || continue
            sed -i '/^ui.minimize_to_tray=/d' "$prefs"
            echo 'ui.minimize_to_tray=true' >> "$prefs"
          done
          spotify >/dev/null 2>&1 &
          spotify_ready() {
            local item
            item=$(busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
              org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems | grep -o '"[^"]*spotify[^"]*"' | tr -d '"') || return 1
            busctl --user get-property "''${item%%/*}" "/''${item#*/}" org.kde.StatusNotifierItem Status \
              | grep Active >/dev/null
          }
          for _ in $(seq 120); do
            if spotify_ready; then
              exec hyprctl dispatch 'hl.dsp.window.close({ window = "class:^(spotify)$" })' >/dev/null
            fi
            sleep 0.5
          done
        '';
      };

      autostart = {
        discord = "discord --start-minimized";
        telegram = "Telegram -startintray";
        signal = "signal-desktop --start-in-tray";
        eagle = "eagle --hidden";
        spotify = "spotify-in-tray";
      };

      appAutostart = pkgs.writeShellApplication {
        name = "app-autostart";
        runtimeInputs = [ pkgs.systemd pkgs.util-linux ];
        text = ''
          apps=(${lib.concatStringsSep " "
            (lib.mapAttrsToList (name: command: lib.escapeShellArg "${name}=${command}") autostart)})

          case "''${1:-start}" in
            list)
              for app in "''${apps[@]}"; do
                printf '%s\t%s\n' "''${app%%=*}" "''${app#*=}"
              done
              ;;
            start)
              for _ in $(seq 120); do
                busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1 && break
                sleep 0.5
              done
              for app in "''${apps[@]}"; do
                [ -z "''${2:-}" ] || [ "''${app%%=*}" = "$2" ] || continue
                read -ra command <<< "''${app#*=}"
                if command -v "''${command[0]}" >/dev/null; then
                  setsid -f "''${command[@]}" >/dev/null 2>&1
                else
                  echo "app-autostart: ''${command[0]} is not installed" >&2
                fi
              done
              ;;
            *)
              echo "usage: app-autostart [list | start [NAME]]" >&2
              exit 2
              ;;
          esac
        '';
      };
    in {
      nixpkgs.config.allowUnfree = true;

      home.packages = builtins.filter supported applications
        ++ lib.optionals pkgs.stdenv.isLinux [ spotifyInTray appAutostart ];

      warnings = map
        (pkg: "Skipping ${pkg.pname}: unavailable on ${pkgs.stdenv.hostPlatform.system}.")
        (builtins.filter (pkg: !supported pkg) applications);
    };
}
