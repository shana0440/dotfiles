set -euo pipefail
umask 077

kind="${1:-}"
file_path="${2:-}"
[[ -s "$file_path" ]] || exit 0

case "$kind" in
    screenshot)
        title="Screenshot saved"
        icon="camera-photo"
        image_path="$file_path"
        ;;
    recording)
        title="Screen recording saved"
        icon="camera-video"
        image_path=""
        preview_directory="${XDG_CACHE_HOME:-$HOME/.cache}/screen-capture/previews"
        mkdir -p -- "$preview_directory"
        preview_path=$(mktemp --suffix=.png "$preview_directory/Recording-XXXXXX")
        if timeout 10s ffmpeg -nostdin -hide_banner -loglevel error -y \
            -i "$file_path" -frames:v 1 -vf 'scale=480:-2' "$preview_path" && [[ -s "$preview_path" ]]; then
            image_path="$preview_path"
        else
            rm -f -- "$preview_path"
        fi
        ;;
    *) exit 2 ;;
esac

hints=(--hint string:desktop-entry:screen-capture)
[[ -z "$image_path" ]] || hints+=(--hint "string:image-path:$image_path")

if [[ "$kind" == recording ]]; then
    timeout 3s notify-send --app-name "Screen Capture" --icon "$icon" \
        "${hints[@]}" -- "$title" "$file_path" || true
    exit 0
fi

forget_quickshell_crash_relaunch_environment() {
    unset "${!__QUICKSHELL_CRASH_@}"
}

action=$(timeout 1h notify-send --app-name "Screen Capture" --icon "$icon" --wait --action edit=Edit \
    "${hints[@]}" -- "$title" "$file_path") || true
if [[ "$action" == edit ]]; then
    forget_quickshell_crash_relaunch_environment
    quickshell ipc call screenshotEditor open "$file_path"
fi
