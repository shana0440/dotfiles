set -euo pipefail
umask 077

recording_mode() {
    local states
    mapfile -t states < <(systemctl --user is-active \
        hypr-record-full.service hypr-record-region.service 2>/dev/null || true)
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
            printf '{"mode":"%s","startedAtSeconds":%s}\n' "$active_mode" "$started_at_seconds"
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
        printf 'Usage: hypr-record {full OUTPUT|region|stop|status}\n' >&2
        exit 2
        ;;
esac

: "${XDG_RUNTIME_DIR:?A Wayland session is required}" "${WAYLAND_DISPLAY:?A Wayland session is required}"
exec {lock_fd}>"$XDG_RUNTIME_DIR/hypr-record.lock"
flock -n "$lock_fd" || exit 1
[[ "$(recording_mode)" == none ]] || exit 1

if [[ "$mode" == region ]]; then
    # slurp reads piped stdin as rectangle suggestions; GUI launches supply none.
    if ! geometry=$(slurp </dev/null); then
        exit 0
    fi
    [[ -n "$geometry" ]] || exit 0
    recorder_args=(-g "$geometry")
fi

recording_directory="${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"
mkdir -p -- "$recording_directory"
recording_path=$(mktemp --suffix=.mp4 "$recording_directory/Recording-$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX")
session_file="$XDG_RUNTIME_DIR/hypr-record-$mode.path"
printf '%s\0' "$recording_path" > "$session_file"

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
