set -euo pipefail
umask 077

case "${1:-}" in
    full|region) mode="$1" ;;
    *) exit 2 ;;
esac

session_file="${XDG_RUNTIME_DIR:?}/hypr-record-$mode.path"
[[ -f "$session_file" ]] || exit 0
IFS= read -r -d '' recording_path < "$session_file" || exit 0
rm -f -- "$session_file"
[[ "${SERVICE_RESULT:-success}" == success && -s "$recording_path" ]] || exit 0

thumbnail_directory="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/recordings"
thumbnail_path="$thumbnail_directory/$(basename -- "$recording_path").png"
if ! mkdir -p -- "$thumbnail_directory" || ! timeout 10s ffmpeg \
    -nostdin -hide_banner -loglevel error -y -i "$recording_path" \
    -frames:v 1 -an -vf 'scale=128:96:force_original_aspect_ratio=decrease' "$thumbnail_path"; then
    rm -f -- "$thumbnail_path" 2>/dev/null || true
    thumbnail_path=""
fi

timeout 1s quickshell --path "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell" \
    ipc call recordings saved "$recording_path" "$thumbnail_path" >/dev/null 2>&1 || true
