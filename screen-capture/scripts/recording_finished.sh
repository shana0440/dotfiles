set -euo pipefail
umask 077

case "${1:-}" in
    full|region|window) mode="$1" ;;
    *) exit 2 ;;
esac

# systemd runs this on success and failure, independently of the application UI.
session_file="${XDG_RUNTIME_DIR:?}/screen-capture-record-$mode.path"
recording_path=""
if [[ -f "$session_file" ]]; then
    IFS= read -r -d '' recording_path < "$session_file" || true
fi
rm -f -- "$session_file"

# The recorder has exited and finalized its output before ExecStopPost runs.
if [[ "${SERVICE_RESULT:-}" == success && -s "$recording_path" ]]; then
    screen-capture-notify recording "$recording_path" || true
fi
