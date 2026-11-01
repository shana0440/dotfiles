{ config, lib, pkgs, ... }:

{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = with pkgs; [ fcitx5-chewing fcitx5-mozc ];
      settings = {
        globalOptions = {
          Behavior.ShareInputState = "All";
          Hotkey = {
            TriggerKeys = "";
            EnumerateSkipFirst = false;
          };
          "Hotkey/EnumerateForwardKeys"."0" = "Control+space";
        };
        inputMethod = {
          GroupOrder."0" = "Default";
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "mozc";
          };
          "Groups/0/Items/0".Name = "keyboard-us";
          "Groups/0/Items/1".Name = "mozc";
          "Groups/0/Items/2".Name = "chewing";
        };
      };
    };
  };

  home.packages = [
    (pkgs.writeShellApplication {
      name = "hypr-toggle-kana";
      runtimeInputs = [ pkgs.systemd ];
      text = ''
        exec ${pkgs.python3}/bin/python3 ${./toggle_kana.py}
      '';
    })
  ];

  # Keep addon preferences writable alongside the managed profile and hotkeys.
  xdg.configFile.fcitx5.recursive = true;

  xdg.configFile."hypr/hyprlock.conf" = lib.mkIf pkgs.stdenv.isLinux {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.dotfiles.directory}/hyprland/hyprlock.conf";
  };

  xdg.configFile."hypr/hyprland.lua" = lib.mkIf pkgs.stdenv.isLinux {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.dotfiles.directory}/hyprland/hyprland.lua";
  };
}
