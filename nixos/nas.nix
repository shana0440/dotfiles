# Optional NAS support. Only encrypted secrets and runtime file paths enter Nix.
{ config, lib, pkgs, ... }:

let
  cfg = config.services.nas;
  user = config.user.name;
  group = config.users.users.${user}.group;
  sopsNix = builtins.fetchTarball {
    url = "https://github.com/Mic92/sops-nix/archive/60182817ee048ac94b4c68ea76d5ef2e8aac730d.tar.gz";
    sha256 = "0fk81bs1c8c3p8ab3152a4hw6qjqkcdli6pw1ndyd56c74fliwk3";
  };
  secretsFile =
    if builtins.pathExists cfg.secretsFile then cfg.secretsFile
    else throw "NAS is enabled but its encrypted secrets file is missing. See nixos/nas/README.md.";
  cleanupMount = ''
    for unit in mnt-nas.automount mnt-nas.mount; do
      load_state=$(systemctl show --property=LoadState --value "$unit")
      if [ "$load_state" != not-found ]; then
        systemctl stop "$unit"
      fi
    done
  '';
  secret = key: {
    sopsFile = secretsFile;
    inherit key;
    mode = "0400";
    restartUnits = [ "nas-automount.service" ];
  };
in
{
  imports = [ "${sopsNix}/modules/sops" ];

  options.services.nas = {
    enable = lib.mkEnableOption "the SOPS-backed on-demand NAS mount at /mnt/nas";
    secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./nas/secrets.enc.yaml;
      description = "SOPS-encrypted YAML containing device and credentials keys.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = [ "cifs" ];

    sops = {
      useSystemdActivation = true;
      age.keyFile = lib.mkDefault "${config.users.users.${user}.home}/.config/sops/age/keys.txt";
      secrets = {
        "nas/device" = secret "device";
        "nas/credentials" = secret "credentials";
      };
    };

    systemd.tmpfiles.rules = [ "d /mnt/nas 0700 ${user} ${group} - -" ];

    # A static mount unit would put its What= (the NAS address) in the Nix store.
    # Create transient mount/automount units after runtime secret decryption instead.
    systemd.services.nas-automount = {
      description = "Configure the on-demand NAS mount from runtime secrets";
      wantedBy = [ "multi-user.target" ];
      requires = [ "sops-install-secrets.service" ];
      after = [ "sops-install-secrets.service" ];
      path = [ pkgs.systemd ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";
      };
      # Remove stale units before retrying; ExecStopPost also runs after failed starts.
      preStart = cleanupMount;
      postStop = cleanupMount;
      script = ''
        device=$(< ${lib.escapeShellArg config.sops.secrets."nas/device".path})
        case "$device" in
          //?*/?*) ;;
          *) echo "Invalid NAS device: expected //HOST/SHARE" >&2; exit 1 ;;
        esac
        systemd-mount --automount=yes --collect --fsck=no --canonicalize=no \
          --type=cifs --description="NAS share" \
          --timeout-idle-sec=0 --property=TimeoutSec=10s \
          --options=${lib.escapeShellArg (lib.concatStringsSep "," [
            "credentials=${config.sops.secrets."nas/credentials".path}"
            "uid=${user}"
            "gid=${group}"
            "rw"
            "file_mode=0600"
            "dir_mode=0700"
            "nosuid"
            "nodev"
            "_netdev"
          ])} \
          "$device" /mnt/nas
      '';
    };
  };
}
