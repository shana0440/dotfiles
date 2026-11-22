set -euo pipefail
umask 077

case "${1:-}" in
    full|region|window) mode="$1" ;;
    *) exit 2 ;;
esac

session_file="${XDG_RUNTIME_DIR:?}/screen-capture-record-$mode.path"
recording_path=""
if [[ -f "$session_file" ]]; then
    IFS= read -r -d '' recording_path < "$session_file" || true
fi
rm -f -- "$session_file"

forget_quickshell_crash_relaunch_environment() {
    unset "${!__QUICKSHELL_CRASH_@}"
}

notify_quickshell() {
    forget_quickshell_crash_relaunch_environment
    timeout 2s quickshell ipc call screenCapture changed >/dev/null 2>&1 || true
}
notify_quickshell

copy_recording_for_nautilus() {
    local file_uri
    file_uri=$(python3 -c 'import sys; from pathlib import Path; print(Path(sys.argv[1]).absolute().as_uri())' "$1") || return
    systemd-run --user --quiet --collect --service-type=exec \
        --setenv="WAYLAND_DISPLAY=$WAYLAND_DISPLAY" \
        --setenv="XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" \
        -- "$(command -v wl-copy)" --foreground --type x-special/gnome-copied-files $'copy\n'"$file_uri"
}

if [[ "${SERVICE_RESULT:-}" == success && -s "$recording_path" ]]; then
    copy_recording_for_nautilus "$recording_path" || true
    screen-capture-notify recording "$recording_path" || true
fi
