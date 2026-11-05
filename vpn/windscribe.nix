{ pkgs, helper ? false }:

let
  version = "2.24.13";
  sources = {
    x86_64-linux = {
      arch = "amd64";
      hash = "sha256-eanxf898hY6NKzHM2umrfabjhA+8kKl0AQTLCsvOGZE=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-pvbcsQ4Uz51bDmdvoE69l3E7/ivf7OFGWB5Psoi8Fls=";
    };
  };
  source = sources.${pkgs.stdenv.hostPlatform.system};
  payload = pkgs.stdenvNoCC.mkDerivation {
    pname = "windscribe-payload";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://github.com/Windscribe/Desktop-App/releases/download/v${version}/windscribe_${version}_${source.arch}.deb";
      inherit (source) hash;
    };
    nativeBuildInputs = [ pkgs.dpkg ];
    unpackPhase = "dpkg-deb -x $src .";
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      mkdir -p $out
      cp -r opt usr/share $out/
    '';
  };
  launcher = pkgs.writeShellScript "windscribe-launch" ''
    export LD_LIBRARY_PATH=/opt/windscribe/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
    case "''${1-}" in
      --cli) shift; exec /opt/windscribe/windscribe-cli "$@" ;;
      *) exec /opt/windscribe/Windscribe "$@" ;;
    esac
  '';
in
pkgs.buildFHSEnv {
  pname = "windscribe";
  inherit version;
  # Upstream binaries and helper scripts require /opt/windscribe and FHS tools.
  targetPkgs = p: with p; [
    acl brotli bzip2 dbus fontconfig freetype glib harfbuzz libdrm libglvnd
    libx11 libxcb libxkbcommon nftables pcre2 systemd
    wayland libxcb-util libxcb-cursor libxcb-image libxcb-keysyms
    libxcb-render-util libxcb-wm zlib zstd
    bash coreutils diffutils findutils gnugrep gnused gawk iproute2
    iptables kmod nettools networkmanager procps util-linux which
    e2fsprogs gnupg
  ];
  multiPkgs = null;
  extraBwrapArgs = [ "--ro-bind ${payload}/opt/windscribe /opt/windscribe" ]
    # Bubblewrap normally drops root capabilities; the helper manages host routes
    # and firewall rules. Only the root system service uses this variant.
    ++ pkgs.lib.optionals helper [ "--cap-add ALL" ];
  runScript = if helper then "/opt/windscribe/helper" else launcher;
  extraInstallCommands = ''
    mkdir -p $out/share/applications
    cp -r ${payload}/share/icons $out/share/
    substitute ${payload}/share/applications/windscribe.desktop \
      $out/share/applications/windscribe.desktop \
      --replace-fail /opt/windscribe/Windscribe $out/bin/windscribe
    printf '#!${pkgs.runtimeShell}\nexec %s --cli "$@"\n' \
      "$out/bin/windscribe" > $out/bin/windscribe-cli
    chmod +x $out/bin/windscribe-cli
  '';
  meta = {
    description = "Windscribe VPN desktop client";
    homepage = "https://windscribe.com";
    license = pkgs.lib.licenses.gpl2Only;
    platforms = builtins.attrNames sources;
    mainProgram = "windscribe";
  };
}
