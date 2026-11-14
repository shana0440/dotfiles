#!/usr/bin/env nix-shell
#! nix-shell -i bash -p sway awww grim wtype wf-recorder
# Runs the lock in a headless sway on the GPU render node, so it never locks your
# own session. PAM accepts only the password "test".
#   run-headless.sh [WALLPAPER] [WIDTHxHEIGHT]
# While it runs, drive it with the tools in its environment, e.g.
#   . "$XDG_RUNTIME_DIR/lock-test.env"; wtype test; wtype -k Return; grim shot.png
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
config="$(cd "$here/../.." && pwd)"
wallpaper="${1:-}"
size="${2:-1707x960}"
tmp="$(mktemp -d)"
env_file="$XDG_RUNTIME_DIR/lock-test.env"
trap 'rm -rf "$tmp"' EXIT

pam_lib="$(nix-build --no-out-link '<nixpkgs>' -A pam)/lib/security"
# pam_exec runs this with an empty environment: no PATH.
cat > "$tmp/check-password" <<EOF
#!/bin/sh
[ "\$($(command -v tr) -d '\\000')" = test ]
EOF
chmod +x "$tmp/check-password"
mkdir "$tmp/pam"
cat > "$tmp/pam/lock-test" <<EOF
auth required $pam_lib/pam_exec.so quiet expose_authtok $tmp/check-password
account required $pam_lib/pam_permit.so
EOF

# Quickshell only imports from inside its config folder: link the real
# folders next to the test shell.
mkdir "$tmp/config"
for dir in Lock Login Theme Icons; do ln -s "$config/$dir" "$tmp/config/$dir"; done
cp "$here/shell.qml" "$tmp/config/shell.qml"

# Inside sway: publish the environment, show the wallpaper, then lock over it.
cat > "$tmp/session" <<EOF
#!/bin/sh
printf 'export WAYLAND_DISPLAY=%s PATH=%s\n' "\$WAYLAND_DISPLAY" "$PATH" > "$env_file"
awww-daemon &
sleep 1
[ -n "$wallpaper" ] && awww img --transition-type none "$wallpaper"
sleep 0.5
export LOCK_TEST_PAM_DIR="$tmp/pam" QT_QPA_PLATFORM=wayland
exec quickshell -p "$tmp/config/shell.qml"
EOF
chmod +x "$tmp/session"

cat > "$tmp/sway.conf" <<EOF
output * resolution $size
default_border none
exec $tmp/session
EOF

unset WAYLAND_DISPLAY DISPLAY
WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=1 WLR_RENDER_DRM_DEVICE=/dev/dri/renderD128 \
    sway --unsupported-gpu -c "$tmp/sway.conf"
