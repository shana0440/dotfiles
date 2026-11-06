# Moshi's host helper (getmoshi.app), not the unrelated Kyutai voice AI.
{ config, lib, pkgs, ... }:

let
  releases = {
    x86_64-linux = {
      platform = "Linux_x86_64";
      sha256 = "793c56b2f02c3e3436e2f82523bb6e1538bfff4de3ec98b6b1e9270d6f167da3";
    };
    aarch64-linux = {
      platform = "Linux_arm64";
      sha256 = "6819898a1135e5454b54d33eeff283265dd3a11257142863259dcf08ad20e77d";
    };
  };
  release = releases.${pkgs.stdenv.hostPlatform.system};
  moshi = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "moshi-hook";
    version = "0.4.50";

    src = pkgs.fetchurl {
      url = "https://cdn.getmoshi.app/hook/v${version}/moshi-hook_${release.platform}.tar.gz";
      inherit (release) sha256;
    };

    sourceRoot = ".";
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 moshi-hook "$out/bin/moshi-hook"
      ln -s moshi-hook "$out/bin/moshi"
      runHook postInstall
    '';

    meta = {
      description = "Moshi mobile terminal host helper and agent hooks";
      homepage = "https://getmoshi.app/";
      license = lib.licenses.unfree;
      platforms = builtins.attrNames releases;
      mainProgram = "moshi";
    };
  };
in
{
  home.packages = [ moshi pkgs.mosh ];

  systemd.user.services.moshi-hook = {
    Unit = {
      Description = "Moshi hook daemon";
      After = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${moshi}/bin/moshi-hook serve";
      Restart = "on-failure";
      RestartSec = 5;
      WorkingDirectory = "%h";
      Environment = [ "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin" ];
    };
    Install.WantedBy = [ "default.target" ];
  };
}
