# Optional NAS support. The plaintext secrets file is read at runtime through its
# absolute path, so its contents never enter the world-readable Nix store.
{ config, lib, pkgs, ... }:

let
  cfg = config.services.nas;
  user = config.user.name;
  group = config.users.users.${user}.group;
  secretsFile =
    if builtins.pathExists cfg.secretsFile then cfg.secretsFile
    else throw "NAS is enabled but ${cfg.secretsFile} is missing. See nixos/nas/README.md.";
  cleanupMount = stopFlags: ''
    for unit in mnt-nas.automount mnt-nas.mount; do
      load_state=$(systemctl show --property=LoadState --value "$unit")
      if [ "$load_state" != not-found ]; then
        systemctl stop ${stopFlags} "$unit"
      fi
    done
  '';
in
{
  options.services.nas = {
    enable = lib.mkEnableOption "the on-demand NAS mount at /mnt/nas";
    secretsFile = lib.mkOption {
      # A string, not a path: a path value would be copied into the Nix store.
      type = lib.types.str;
      default = toString ./nas/secrets.yaml;
      description = "Absolute path to the plaintext YAML whose device key is HOST:/EXPORT/PATH.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = [ "nfs" ];

    systemd.tmpfiles.rules = [ "d /mnt/nas 0700 ${user} ${group} - -" ];

    # A static mount unit would put its What= (the NAS address) in the Nix store.
    # Create transient mount/automount units from the runtime secrets file instead.
    systemd.services.nas-automount = {
      description = "Configure the on-demand NAS mount from runtime secrets";
      wantedBy = [ "multi-user.target" ];
      # The secrets file lives in the dotfiles checkout under /home.
      unitConfig.RequiresMountsFor = [ secretsFile ];
      path = [ pkgs.systemd pkgs.nfs-utils pkgs.yq-go ];
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
        device=$(yq -e '.device' ${lib.escapeShellArg secretsFile})
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
