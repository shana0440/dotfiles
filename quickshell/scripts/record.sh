set -euo pipefail
umask 077

recording_mode() {
    local output query_status=0 states
    output=$(systemctl --user is-active \
        hypr-record-full.service hypr-record-region.service) || query_status=$?
    # is-active returns 3 when none of the requested units are active.
    case "$query_status" in
        0|3) ;;
        *) return "$query_status" ;;
    esac
    mapfile -t states <<< "$output"
    case "${states[0]:-}" in
        active|activating|deactivating) printf 'full\n'; return ;;
    esac
    case "${states[1]:-}" in
        active|activating|deactivating) printf 'region\n'; return ;;
    esac
    printf 'none\n'
}

mode="${1:-}"
case "$mode" in
    status)
        active_mode=$(recording_mode)
        if [[ "${2:-}" == --json ]]; then
            started_at_seconds=0
            if [[ "$active_mode" != none && -n "${XDG_RUNTIME_DIR:-}" ]]; then
                started_at_seconds=$(stat -c %Y "$XDG_RUNTIME_DIR/hypr-record-$active_mode.path" 2>/dev/null || printf '0')
            fi
            recording_geometry=""
            session_file="${XDG_RUNTIME_DIR:-}/hypr-record-$active_mode.path"
            if [[ "$active_mode" == region && -n "${XDG_RUNTIME_DIR:-}" && -f "$session_file" ]]; then
                {
                    IFS= read -r -d '' _ || true
                    IFS= read -r -d '' recording_geometry || true
                } < "$session_file" 2>/dev/null || recording_geometry=""
                if [[ ! "$recording_geometry" =~ ^-?[0-9]+,-?[0-9]+\ [1-9][0-9]*x[1-9][0-9]*$ ]]; then
                    recording_geometry=""
                fi
            fi
            printf '{"mode":"%s","startedAtSeconds":%s,"geometry":"%s"}\n' \
                "$active_mode" "$started_at_seconds" "$recording_geometry"
        else
            printf '%s\n' "$active_mode"
        fi
        exit 0
        ;;
    stop)
        active_mode=$(recording_mode)
        if [[ "$active_mode" != none ]]; then
            systemctl --user stop "hypr-record-$active_mode.service"
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
    *)
        printf 'Usage: hypr-record {full OUTPUT|region [OUTPUT GEOMETRY]|stop|status}\n' >&2
        exit 2
        ;;
esac

: "${XDG_RUNTIME_DIR:?A Wayland session is required}" "${WAYLAND_DISPLAY:?A Wayland session is required}"
exec {lock_fd}>"$XDG_RUNTIME_DIR/hypr-record.lock"
flock -n "$lock_fd" || exit 1
active_mode=$(recording_mode)
[[ "$active_mode" == none ]] || exit 1

geometry=""
if [[ "$mode" == region ]]; then
    geometry="${3:-}"
    if [[ -z "$geometry" ]]; then
        if timeout 1s quickshell --path "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell" \
            ipc call capture selectRegion recording >/dev/null 2>&1; then
            exit 0
        fi
        # slurp reads piped stdin as rectangle suggestions; GUI launches supply none.
        if ! geometry=$(slurp </dev/null); then
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
session_file="$XDG_RUNTIME_DIR/hypr-record-$mode.path"
printf '%s\0%s\0' "$recording_path" "$geometry" > "$session_file"

# The recorder outlives shell reloads; SIGINT lets it finalize the MP4 when stopped.
# Select the playback monitor explicitly so the microphone stays excluded.
if ! systemd-run --user --quiet --collect --service-type=exec \
    --unit="hypr-record-$mode.service" \
    --property=KillSignal=SIGINT --property=TimeoutStopSec=15s \
    --property="ExecStopPost=$(command -v hypr-recording-finished) $mode" \
    --setenv="XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}" \
    --setenv="XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}" \
    --setenv="WAYLAND_DISPLAY=$WAYLAND_DISPLAY" \
    --setenv="XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" \
    -- "$(command -v wf-recorder)" --overwrite \
    --audio-backend=pulse --audio=@DEFAULT_MONITOR@ --audio-codec=aac \
    "${recorder_args[@]}" -f "$recording_path"; then
    rm -f -- "$recording_path" "$session_file"
    exit 1
fi
printf '%s\n' "$recording_path"
