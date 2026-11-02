{ pkgs }:

let
  # Upstream's Ubuntu 26.04 release requires GLIBC_2.43. Keep its newer runtime
  # local to this package rather than upgrading the host's NixOS/Home Manager.
  runtimePkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/1c89083e451e891152365b799595cf7790a43325.tar.gz";
    sha256 = "0gnw7gkrh9axnknb67627mf9sbdd7sbgw3148g5lh1d8hiks4l33";
  }) { system = pkgs.stdenv.hostPlatform.system; };
  releases = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-Zm0AO38Xr3/2h5hCzWjteCd5psqCBMiYUYVxhHDP9Js=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-iM1IehIGDLiJ6cwAEq76AyRnOXeFmCHycpqsvhzt3Mw=";
    };
  };
  release = releases.${pkgs.stdenv.hostPlatform.system};
  commands = with pkgs; [
    coreutils dbus imagemagick openbox xorg-server xauth xclip xdotool
    xdpyinfo xprop xwininfo xterm
    kdePackages.kwin kdePackages.kservice kdePackages.libkscreen
    bubblewrap grim wtype wl-clipboard hyprland xwayland
  ];
in
runtimePkgs.stdenv.mkDerivation rec {
  pname = "agent-workspace-linux";
  version = "0.6.3";
  src = runtimePkgs.fetchurl {
    url = "https://github.com/agent-sh/agent-workspace-linux/releases/download/v${version}/agent-workspace-linux-${release.target}";
    inherit (release) hash;
  };
  dontUnpack = true;
  dontStrip = true;
  nativeBuildInputs = with runtimePkgs; [ autoPatchelfHook makeWrapper ];
  buildInputs = with runtimePkgs; [ libxcb libxkbcommon stdenv.cc.cc.lib ];
  runtimeDependencies = map runtimePkgs.lib.getLib (with runtimePkgs; [
    libglvnd vulkan-loader wayland fontconfig freetype libX11
  ]);
  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/agent-workspace-linux"
    runHook postInstall
  '';
  postFixup = ''
    wrapProgram "$out/bin/agent-workspace-linux" \
      --prefix PATH : ${pkgs.lib.makeBinPath commands}
  '';
  meta = {
    description = "Private desktop workspaces for agents, controlled through CLI or MCP";
    homepage = "https://github.com/agent-sh/agent-workspace-linux";
    license = pkgs.lib.licenses.mit;
    platforms = builtins.attrNames releases;
    mainProgram = "agent-workspace-linux";
  };
}
