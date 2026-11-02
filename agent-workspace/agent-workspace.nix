# Opt-in by import in the desktop Linux Home Manager profile only.
{ pkgs, ... }:

let
  workspaceConfig = pkgs.applyPatches {
    name = "agent-workspace-quickshell-config";
    src = ../quickshell/config;
    patches = [ ./quickshell-legacy-dispatch.patch ];
  };
  workspaceQuickshell = pkgs.writeShellApplication {
    name = "agent-workspace-quickshell";
    runtimeInputs = [ pkgs.coreutils pkgs.quickshell ];
    text = ''
      : "''${AGENT_WORKSPACE_RUNTIME_DIR:?Launch this through agent-workspace-linux workspace launch}"
      runtime=$(realpath "$AGENT_WORKSPACE_RUNTIME_DIR")
      ipc=$(< "$runtime/hyprland-ipc")
      if [[ "$ipc" != "$runtime/hypr/"*"/.socket.sock" || ! -S "$ipc" ]]; then
        echo "No verified private Hyprland IPC socket in this workspace." >&2
        exit 1
      fi
      export HYPRLAND_INSTANCE_SIGNATURE
      HYPRLAND_INSTANCE_SIGNATURE=$(basename "$(dirname "$ipc")")

      # Qt cannot connect to the long socket paths under the workspace runtime.
      short=$(mktemp -d /tmp/aqsXXXXXX)
      trap 'rm -f "$short/r"; rmdir "$short"' EXIT
      trap 'exit 130' INT
      trap 'exit 143' TERM
      ln -s "$runtime" "$short/r"
      export XDG_RUNTIME_DIR="$short/r"

      # Keep this config and its IPC clients separate from the host shell.
      export XDG_CONFIG_HOME="$runtime/quickshell-session-config"
      mkdir -p "$XDG_CONFIG_HOME"
      ln -sfn ${workspaceConfig} "$XDG_CONFIG_HOME/quickshell"
      quickshell --path "$XDG_CONFIG_HOME/quickshell" "$@"
    '';
  };
in
{
  home.packages = [
    (import ./package.nix { inherit pkgs; })
    workspaceQuickshell
  ];
}
