{ config, lib, pkgs, ... }:

let
  cfg = config.services.nas;
  user = config.user.name;
  group = config.users.users.${user}.group;
  secretsFile =
    if builtins.pathExists cfg.secretsFile then cfg.secretsFile
    else throw "NAS is enabled but ${cfg.secretsFile} is missing. See nixos/nas/README.md.";
  stopMountUnits = stopFlags: ''
    for unit in mnt-nas.automount mnt-nas.mount; do
      load_state=$(systemctl show --property=LoadState --value "$unit")
      if [ "$load_state" != not-found ]; then
        systemctl stop ${stopFlags} "$unit"
      fi
    done
  '';
  waitForStaleUnitsToStop = stopMountUnits "";
  queueStopWithoutBlockingShutdown = stopMountUnits "--no-block";
in
{
  options.services.nas = {
    enable = lib.mkEnableOption "the on-demand NAS mount at /mnt/nas";
    secretsFile = lib.mkOption {
      type = lib.types.str;
      default = toString ./nas/secrets.yaml;
      description = "Absolute path to the plaintext YAML whose device key is HOST:/EXPORT/PATH.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = [ "nfs" ];

    systemd.tmpfiles.rules = [ "d /mnt/nas 0700 ${user} ${group} - -" ];

    systemd.services.nas-automount = {
      description = "Configure the on-demand NAS mount from runtime secrets";
      wantedBy = [ "multi-user.target" ];
      unitConfig.RequiresMountsFor = [ secretsFile ];
      path = [ pkgs.systemd pkgs.nfs-utils pkgs.yq-go ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStopSec = "15s";
        UMask = "0077";
      };
      preStart = waitForStaleUnitsToStop;
      postStop = queueStopWithoutBlockingShutdown;
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
