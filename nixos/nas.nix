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
  cleanupMount = stopFlags: ''
    for unit in mnt-nas.automount mnt-nas.mount; do
      load_state=$(systemctl show --property=LoadState --value "$unit")
      if [ "$load_state" != not-found ]; then
        systemctl stop ${stopFlags} "$unit"
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
      description = "SOPS-encrypted YAML containing the NFS device key (HOST:/EXPORT/PATH).";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = [ "nfs" ];

    sops = {
      useSystemdActivation = true;
      age.keyFile = lib.mkDefault "${config.users.users.${user}.home}/.config/sops/age/keys.txt";
      secrets = {
        "nas/device" = secret "device";
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
      path = [ pkgs.systemd pkgs.nfs-utils ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStopSec = "15s";
        UMask = "0077";
      };
      # Wait for stale units before starting a replacement mount.
      preStart = cleanupMount "";
      # ExecStopPost also runs after failed starts. Only queue stop jobs here:
      # waiting for mount jobs during shutdown can block on systemd ordering.
      # systemd still waits for the queued unmount jobs before finishing shutdown.
      postStop = cleanupMount "--no-block";
      script = ''
        device=$(< ${lib.escapeShellArg config.sops.secrets."nas/device".path})
        case "$device" in
          ?*:/?*) ;;
          *) echo "Invalid NAS device: expected HOST:/EXPORT/PATH" >&2; exit 1 ;;
        esac
        systemd-mount --automount=yes --collect --fsck=no --canonicalize=no \
          --type=nfs --description="NAS share (NFSv4)" \
          --timeout-idle-sec=0 --property=TimeoutSec=10s \
          --options=${lib.escapeShellArg (lib.concatStringsSep "," [
            "vers=4.0"
            "proto=tcp"
            "hard"
            "rw"
            "nosuid"
            "nodev"
            "_netdev"
          ])} \
          "$device" /mnt/nas
      '';
    };
  };
}
