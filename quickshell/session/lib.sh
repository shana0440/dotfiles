set -euo pipefail

session_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "$session_dir/../.." && pwd)
scenario=$(basename "$0" .sh)
evidence=$(realpath -m "${SESSION_EVIDENCE:-$(dirname "$0")}")
pipewire_dir=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
wallpaper_dir=${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}
lock_password=test
work=$(mktemp -d /tmp/st.XXXXXX)
rt=$work/rt
segments=0
mkdir -p "$rt" "$work"/{state,data,bin,pam,config,kwin-config,pictures} "$evidence"
chmod 700 "$rt"

log() { printf '[%s] %s\n' "$scenario" "$*" >&2; }

session_pids() {
    local d p
    for d in /proc/[0-9]*; do
        p=${d#/proc/}
        [ "$p" = $$ ] && continue
        if tr '\0' '\n' < "$d/environ" 2>/dev/null | grep -qx "XDG_RUNTIME_DIR=$rt" \
            || tr '\0' ' ' < "$d/cmdline" 2>/dev/null | grep -qF "$work/hyprland.lua"; then
            echo "$p"
        fi
    done 2>/dev/null
}

session_pids_named() {
    local p
    for p in $(session_pids); do
        case "$(tr '\0' ' ' 2>/dev/null < "/proc/$p/cmdline")" in
            "$1 "* | */"$1 "*) echo "$p" ;;
        esac
    done
}

signal_named() { local p; for p in $(session_pids_named "$2"); do kill "$1" "$p" 2>/dev/null || true; done; }

session_cleanup() {
    local status=$? logs=$evidence/$scenario-logs p mount
    if [ -d "$work/mei/state/logs" ]; then
        mkdir -p "$logs/mei"
        cp -r "$work/mei/state/logs/." "$logs/mei/"
        log "mei logs saved to $logs/mei/"
    fi
    if [ -n "${SESSION_KEEP:-}" ] && [ "$status" -ne 0 ]; then
        log "kept $work for debugging; kill its processes and remove it when done"
        return
    fi
    if [ "$status" -ne 0 ]; then
        mkdir -p "$logs"
        cp "$work"/*.log "$logs/" 2>/dev/null || true
        log "logs saved to $logs/"
        if [ "$segments" -gt 0 ]; then
            record_stop || true
            mkdir -p "$logs/segments"
            cp "$work"/segment-*.mp4 "$logs/segments/" 2>/dev/null || true
            log "partial recordings saved to $logs/segments/"
        fi
    fi
    log "cleaning up"
    for p in $(session_pids); do kill -9 "$p" 2>/dev/null || true; done
    sleep 1
    for mount in $(awk -v w="$work" 'index($2, w) == 1 {print $2}' /proc/mounts); do
        fusermount3 -u "$mount" 2>/dev/null || fusermount -u "$mount" 2>/dev/null || true
    done
    rm -rf "$work"
}
trap session_cleanup EXIT
trap 'exit 130' INT TERM

wait_for() {
    local tries=$1; shift
    until "$@" >/dev/null 2>&1; do
        tries=$((tries - 1))
        [ "$tries" -gt 0 ] || { log "timed out waiting for: $*"; failure_shot; return 1; }
        sleep 0.5
    done
}

isolated() {
    env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u QT_QPA_PLATFORM -u SWAYSOCK \
        XDG_RUNTIME_DIR="$rt" XDG_STATE_HOME="$work/state" XDG_DATA_HOME="$work/data" \
        PIPEWIRE_RUNTIME_DIR="$pipewire_dir" WALLPAPER_SHELL="$work/config" WALLPAPER_DIR="$wallpaper_dir" \
        XDG_PICTURES_DIR="$work/pictures" MEI_HOME="$work/mei" \
        GTK_THEME=adw-gtk3-dark ADW_DEBUG_COLOR_SCHEME=prefer-dark \
        LD_LIBRARY_PATH=/run/opengl-driver/lib \
        PATH="$work/bin:$wf_recorder/bin:$grim/bin:$wl_clipboard/bin:$PATH" "$@"
}
host() { isolated WAYLAND_DISPLAY=wayland-1 DBUS_SESSION_BUS_ADDRESS="$(cat "$work/bus")" "$@"; }
hypr_display() { (cd "$rt" && ls wayland-* 2>/dev/null | grep -v -e lock -e '^wayland-1$' | head -1); }
hypr() {
    isolated WAYLAND_DISPLAY="$(hypr_display)" HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "$rt/hypr" | head -1)" \
        DBUS_SESSION_BUS_ADDRESS="$(cat "$work/bus")" "$@"
}
background() { ("$@") < /dev/null & }

shell_ipc() { hypr quickshell --path "$work/config" ipc call "$@"; }
has_client() { hypr hyprctl clients | grep -q "class: $1\$"; }
lacks_client() { ! has_client "$1"; }
has_layer() { hypr hyprctl layers | grep -q "namespace: $1,"; }
lacks_layer() { ! has_layer "$1"; }
active_class_is() { hypr hyprctl activewindow | grep -q "class: $1\$"; }
active_workspace_is() {
    hypr hyprctl -j activeworkspace | "$python/bin/python3" -c \
        'import json, sys; sys.exit(json.load(sys.stdin)["id"] != int(sys.argv[1]))' "$1"
}
brightness() { hypr grim -g "$1" - | "$magick/bin/magick" - -format '%[fx:mean*1000]' info: | cut -d. -f1; }
clipboard() { hypr wl-paste -n; }
mei_answered() {
    [ "$(isolated mei status | grep -Ec '^#[0-9]+  user.message  (done|failed)')" -ge "${1:-1}" ]
}

send() { timeout 3 sh -c 'echo "$1" > "$2"' _ "$*" "$work/input.fifo" || { log "input daemon stopped"; exit 1; }; }
move() { send move "$1" "$2"; sleep "${3:-0.8}"; }
click() { send click; sleep "${1:-1}"; }
right_click() { send rightclick; sleep "${1:-1}"; }
click_at() { move "$1" "$2" 0.4; click "${3:-1}"; }
press() { send key "$1"; sleep "${2:-1}"; }
type_text() { send type "$1"; sleep "${2:-1}"; }
scroll_down() { local _; for _ in $(seq "${1:-1}"); do send scroll 120; sleep 0.15; done; sleep "${2:-0.5}"; }
scroll_up() { local _; for _ in $(seq "${1:-1}"); do send scroll -120; sleep 0.15; done; sleep "${2:-0.5}"; }
drag() {
    local x1=$1 y1=$2 x2=$3 y2=$4 step
    move "$x1" "$y1" 0.3; send down; sleep 0.2
    for step in 1 2 3 4 5 6; do
        move $((x1 + (x2 - x1) * step / 6)) $((y1 + (y2 - y1) * step / 6)) 0.08
    done
    send up; sleep "${5:-0.5}"
}
click_until() {
    local x=$1 y=$2 attempt; shift 2
    for attempt in 1 2 3; do
        click_at "$x" "$y" 0.2
        wait_for 6 "$@" && return
    done
    log "clicking $x,$y never reached: $*"; failure_shot; return 1
}

shot() {
    local file=$evidence/$scenario-$1.png
    hypr grim "$file"
    log "screenshot $file"
}
failure_shot() {
    [ -n "$(hypr_display)" ] || return 0
    hypr grim "$evidence/$scenario-failure.png" 2>/dev/null && log "screen saved to $evidence/$scenario-failure.png"
    hypr hyprctl clients 2>/dev/null | grep -E 'class:|workspace:' >&2 || true
}

recorder_stopped() { [ -z "$(session_pids_named wf-recorder)" ]; }
record_start() {
    segments=$((segments + 1))
    background hypr wf-recorder -y --no-dmabuf -r 30 -c libx264 -p preset=veryfast -p crf=20 \
        -f "$work/segment-$segments.mp4" > "$work/recorder-$segments.log" 2>&1
    sleep 1.5
}
record_stop() {
    local nudge
    signal_named -INT wf-recorder
    for nudge in $(seq 20); do
        recorder_stopped && return
        send move $((1200 + nudge % 2)) 900; sleep 0.5
    done
    log "recorder did not stop"; return 1
}
record_save() {
    local output=${1:-$evidence/$scenario.mp4}
    recorder_stopped || record_stop
    printf "file %s\n" "$work"/segment-*.mp4 > "$work/segments.txt"
    "$ffmpeg/bin/ffmpeg" -loglevel error -y -f concat -safe 0 -i "$work/segments.txt" -c copy "$output"
    log "recording $output"
}

fetch_tools() {
    log "fetching tools"
    local paths
    mapfile -t paths < <(nix build --no-link --print-out-paths \
        nixpkgs#kdePackages.kwin nixpkgs#libei nixpkgs#wf-recorder nixpkgs#grim \
        nixpkgs#imagemagick nixpkgs#ffmpeg.bin nixpkgs#wl-clipboard)
    kwin=${paths[0]} libei=${paths[1]} wf_recorder=${paths[2]} grim=${paths[3]}
    magick=${paths[4]} ffmpeg=${paths[5]} wl_clipboard=${paths[6]}
    python=$(nix build --no-link --print-out-paths --impure --expr \
        '((builtins.getFlake "nixpkgs").legacyPackages.${builtins.currentSystem}.python3.withPackages (p: [ p.dbus-python ]))' | tail -1)
    pam_lib=$(dirname "$(grep -oh '/nix/store/[^ ]*/pam_permit.so' /etc/pam.d/* | head -1)")
    local tool
    for tool in Hyprland start-hyprland quickshell mei awww awww-daemon vicinae wallpaper-library "$@"; do
        command -v "$tool" >/dev/null || { log "missing $tool"; exit 1; }
    done
}

prepare_shell_config() {
    local entry
    for entry in "$repo"/quickshell/config/*; do
        [ "$(basename "$entry")" = shell.qml ] || ln -s "$entry" "$work/config/"
    done
    sed 's|    Lock {}|    Lock {\n        pamConfig: "lock-test"\n        pamDirectory: Quickshell.env("LOCK_TEST_PAM_DIR")\n    }|' \
        "$repo/quickshell/config/shell.qml" > "$work/config/shell.qml"
    grep -q lock-test "$work/config/shell.qml" || { log "could not point the lock at the test password"; exit 1; }
    sed -i '1i import QtQuick' "$work/config/shell.qml"
    sed -i '/ShellRoot {/a\    Connections {\n        target: Services.Capture\n        function onErrorOccurred(message) { console.warn("Session capture error: " + message) }\n    }' "$work/config/shell.qml"

    printf '#!/bin/sh\n[ "$(%s -d '"'"'\\000'"'"')" = %s ]\n' "$(command -v tr)" "$lock_password" > "$work/check-password"
    chmod +x "$work/check-password"
    cat > "$work/pam/lock-test" <<EOF
auth required $pam_lib/pam_exec.so quiet expose_authtok $work/check-password
account required $pam_lib/pam_permit.so
EOF
    printf '#!/bin/sh\nexec sleep infinity\n' > "$work/bin/bluetooth-pairing-agent"
    chmod +x "$work/bin/bluetooth-pairing-agent"
    local record_command
    record_command=$(command -v screen-capture-record)
    cat > "$work/bin/screen-capture-record" <<EOF
#!/bin/sh
if [ "\$1" = status ]; then
    exec env XDG_RUNTIME_DIR="$pipewire_dir" DBUS_SESSION_BUS_ADDRESS="unix:path=$pipewire_dir/bus" "$record_command" "\$@"
fi
exec "$record_command" "\$@"
EOF
    chmod +x "$work/bin/screen-capture-record"
}

prepare_hyprland() {
    perl -0pe '
        s|"quickshell --path ~/.config/quickshell ipc call "|"quickshell --path '"$work"'/config ipc call "|;
        s|mode     = "preferred",|mode     = "1920x1080\@60",|;
        s|scale    = "auto",|scale    = 1,|;
        s|hl.on\("hyprland.start", function \(\)\n.*?\nend\)|hl.on("hyprland.start", function ()\n    hl.exec_cmd("vicinae server")\n    hl.exec_cmd("'"$work"'/session-start")\nend)|s;
    ' "$repo/hyprland/hyprland.lua" > "$work/hyprland.lua"
    cat >> "$work/hyprland.lua" <<'EOF'

hl.config({ cursor = { no_hardware_cursors = true } })
hl.config({ misc = { initial_workspace_tracking = 0 } })
hl.config({ input = { scroll_factor = 0.5 } })
EOF
    local expected
    for expected in "$work/config ipc call" "1920x1080@60" "scale    = 1," "$work/session-start"; do
        grep -qF "$expected" "$work/hyprland.lua" || { log "hyprland.lua changed shape; could not apply: $expected"; exit 1; }
    done

    wallpaper_library=$(WALLPAPER_DIR="$wallpaper_dir" wallpaper-library)
    local recorded
    recorded=$(head -n 1 "${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper/current" 2>/dev/null || true)
    start_wallpaper=$("$python/bin/python3" -c '
import json, sys
paths = [item["path"] for item in json.loads(sys.argv[1])["items"]]
print(sys.argv[2] if sys.argv[2] in paths else paths[0])' "$wallpaper_library" "$recorded")
    cat > "$work/session-start" <<EOF
#!/bin/sh
awww-daemon > $work/awww.log 2>&1 &
sleep 0.5
awww img --transition-type none "$start_wallpaper"
export QT_QPA_PLATFORM=wayland LOCK_TEST_PAM_DIR=$work/pam
exec quickshell -p $work/config > $work/quickshell.log 2>&1
EOF
    cat > "$work/host-session" <<EOF
#!/bin/sh
printf '%s' "\$DBUS_SESSION_BUS_ADDRESS" > $work/bus
exec sleep infinity
EOF
    chmod +x "$work/session-start" "$work/host-session"
    printf '[Windows]\nPlacement=Maximizing\nBorderlessMaximizedWindows=true\n' > "$work/kwin-config/kwinrc"
}

start_mei() {
    log "starting mei with a copy of your settings"
    local template
    template=$(dirname "$(dirname "$(readlink -f "$(command -v mei)")")")/lib/mei/template
    mkdir -p "$work/mei"
    cp -r --no-preserve=mode "$template/." "$work/mei"
    (
        shopt -s dotglob nullglob
        for entry in "$HOME/.local/share/mei"/*; do
            case "$(basename "$entry")" in state|memory) continue ;; esac
            cp -r --no-preserve=mode "$entry" "$work/mei/"
        done
    )
    background isolated mei-daemon > "$work/mei.log" 2>&1
    wait_for 60 test -S "$work/mei/state/mei.sock"
}

monitor_ready() { hypr hyprctl monitors | grep -q 1920x1080; }
hyprland_ready() {
    local directory
    for directory in "$rt"/hypr/*; do
        [ -S "$directory/.socket.sock" ] && [ -S "$directory/.socket2.sock" ] || continue
        [ "${#directory}" -le 93 ] || { log "Hyprland socket path is too long: $directory"; return 1; }
        return 0
    done
    return 1
}
hypr_display_ready() { [ -n "$(hypr_display)" ]; }
shell_ready() { hypr quickshell --path "$work/config" ipc show; }

session_start() {
    local with_mei=""
    if [ "${1:-}" = --mei ]; then with_mei=1; shift; fi
    fetch_tools "$@"
    [ -z "$with_mei" ] || command -v mei-daemon >/dev/null || { log "missing mei-daemon"; exit 1; }
    log "preparing the session in $work"
    prepare_shell_config
    prepare_hyprland

    log "starting the hidden KWin host"
    background isolated XDG_CONFIG_HOME="$work/kwin-config" dbus-run-session -- "$kwin/bin/kwin_wayland" --virtual \
        --width 1920 --height 1080 --no-lockscreen --no-global-shortcuts --no-kactivities \
        --socket wayland-1 --exit-with-session "$work/host-session" > "$work/kwin.log" 2>&1
    wait_for 40 test -s "$work/bus"

    background host "$python/bin/python3" -u "$session_dir/input.py" "$libei/lib/libei.so.1" "$work/input.fifo" \
        > "$work/input.log" 2>&1
    wait_for 40 grep -q ready "$work/input.log"

    [ -z "$with_mei" ] || start_mei

    log "starting nested Hyprland"
    background host start-hyprland -- -c "$work/hyprland.lua" > "$work/hyprland.log" 2>&1
    wait_for 60 hyprland_ready
    wait_for 40 hypr_display_ready
    wait_for 40 monitor_ready
    wait_for 60 shell_ready
    press alt+1 0.5
    move 1200 900
}
