set -euo pipefail

slurp_without_rectangle_suggestions() {
    slurp </dev/null
}
umask 077

recording_mode() {
    local output query_status=0 states
    local units_exist_but_none_active=3 units_already_collected=4
    output=$(systemctl --user is-active \
        screen-capture-record-full.service screen-capture-record-region.service screen-capture-record-window.service) || query_status=$?
    case "$query_status" in
        0|"$units_exist_but_none_active"|"$units_already_collected") ;;
        *) return "$query_status" ;;
    esac
    mapfile -t states <<< "$output"
    case "${states[0]:-}" in
        active|activating|deactivating) printf 'full\n'; return ;;
    esac
    case "${states[1]:-}" in
        active|activating|deactivating) printf 'region\n'; return ;;
    esac
    case "${states[2]:-}" in
        active|activating|deactivating) printf 'window\n'; return ;;
    esac
    printf 'none\n'
}

forget_quickshell_crash_relaunch_environment() {
    unset "${!__QUICKSHELL_CRASH_@}"
}

notify_quickshell_without_waiting_for_its_poll() {
    {
        forget_quickshell_crash_relaunch_environment
        QS_CONFIG_PATH="${QS_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell}" \
            timeout 2s quickshell ipc call screenCapture changed
    } >/dev/null 2>&1 &
}

mode="${1:-}"
case "$mode" in
    status)
        active_mode=$(recording_mode)
        if [[ "${2:-}" == --json ]]; then
            started_at_seconds=0
            if [[ "$active_mode" != none && -n "${XDG_RUNTIME_DIR:-}" ]]; then
                started_at_seconds=$(stat -c %Y "$XDG_RUNTIME_DIR/screen-capture-record-$active_mode.path" 2>/dev/null || printf '0')
            fi
            recording_geometry=""
            recording_window=""
            session_file="${XDG_RUNTIME_DIR:-}/screen-capture-record-$active_mode.path"
            if [[ "$active_mode" != none && -n "${XDG_RUNTIME_DIR:-}" && -f "$session_file" ]]; then
                {
                    IFS= read -r -d '' _ || true
                    IFS= read -r -d '' recording_geometry || true
                    IFS= read -r -d '' recording_window || true
                } < "$session_file" 2>/dev/null || { recording_geometry=""; recording_window=""; }
                if [[ "$active_mode" != region || ! "$recording_geometry" =~ ^-?[0-9]+,-?[0-9]+\ [1-9][0-9]*x[1-9][0-9]*$ ]]; then
                    recording_geometry=""
                fi
                if [[ "$active_mode" != window || ! "$recording_window" =~ ^[0-9a-fA-F]+$ ]]; then
                    recording_window=""
                fi
            fi
            printf '{"mode":"%s","startedAtSeconds":%s,"geometry":"%s","window":"%s"}\n' \
                "$active_mode" "$started_at_seconds" "$recording_geometry" "$recording_window"
        else
            printf '%s\n' "$active_mode"
        fi
        exit 0
        ;;
    stop)
        active_mode=$(recording_mode)
        if [[ "$active_mode" != none ]]; then
            systemctl --user stop "screen-capture-record-$active_mode.service"
            notify_quickshell_without_waiting_for_its_poll
        fi
        exit 0
        ;;
    full)
        if [[ -z "${2:-}" ]]; then
            printf 'Full-screen recording requires an output name.\n' >&2
            exit 2
        fi
        recorder_args=(-o "$2")
        ;;
    region)
        recorder_args=()
        ;;
    window)
        if [[ ! "${2:-}" =~ ^[0-9a-fA-F]+$ ]]; then
            printf 'Window recording requires a native window identifier.\n' >&2
            exit 2
        fi
        ;;
    *)
        printf 'Usage: screen-capture-record {full OUTPUT|region [OUTPUT GEOMETRY]|window IDENTIFIER|stop|status}\n' >&2
        exit 2
        ;;
esac

: "${XDG_RUNTIME_DIR:?A Wayland session is required}" "${WAYLAND_DISPLAY:?A Wayland session is required}"
exec {lock_fd}>"$XDG_RUNTIME_DIR/screen-capture-record.lock"
flock -n "$lock_fd" || exit 1
active_mode=$(recording_mode)
[[ "$active_mode" == none ]] || exit 1

if [[ "$mode" == window ]]; then
    screen-capture-window-record --check "$2"
fi

geometry=""
if [[ "$mode" == region ]]; then
    geometry="${3:-}"
    if [[ -z "$geometry" ]]; then
        if ! geometry=$(slurp_without_rectangle_suggestions); then
            exit 0
        fi
        [[ -n "$geometry" ]] || exit 0
    fi
    if [[ ! "$geometry" =~ ^-?[0-9]+,-?[0-9]+\ [1-9][0-9]*x[1-9][0-9]*$ ]]; then
        printf 'Invalid recording geometry.\n' >&2
        exit 2
    fi
    recorder_args=(-g "$geometry")
fi

recording_directory="${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"
mkdir -p -- "$recording_directory"
recording_path=$(mktemp --suffix=.mp4 "$recording_directory/Recording-$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX")
session_file="$XDG_RUNTIME_DIR/screen-capture-record-$mode.path"
window_identifier=""
[[ "$mode" != window ]] || window_identifier="$2"
printf '%s\0%s\0%s\0' "$recording_path" "$geometry" "$window_identifier" > "$session_file"

if [[ "$mode" == window ]]; then
    recorder_command=("$(command -v screen-capture-window-record)" "$2" "$recording_path")
else
    playback_only_without_microphone=@DEFAULT_MONITOR@
    recorder_command=("$(command -v wf-recorder)" --overwrite
        --audio-backend=pulse --audio="$playback_only_without_microphone" --audio-codec=aac
        "${recorder_args[@]}" -f "$recording_path")
fi

finalize_mp4_on_stop=SIGINT
if ! systemd-run --user --quiet --collect --service-type=exec \
    --unit="screen-capture-record-$mode.service" \
    --property=KillSignal="$finalize_mp4_on_stop" --property=TimeoutStopSec=15s \
    --property="ExecStopPost=$(command -v screen-capture-recording-finished) $mode" \
    --setenv="XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}" \
    --setenv="XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}" \
    --setenv="DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}" \
    --setenv="WAYLAND_DISPLAY=$WAYLAND_DISPLAY" \
    --setenv="XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" \
    -- "${recorder_command[@]}"; then
    rm -f -- "$recording_path" "$session_file"
    exit 1
fi
notify_quickshell_without_waiting_for_its_poll
printf '%s\n' "$recording_path"
