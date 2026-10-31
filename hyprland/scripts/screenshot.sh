set -euo pipefail

notify_screenshot_saved() {
    local shell_config="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
    # Saving and clipboard delivery must work while Quickshell is unavailable.
    timeout 1s quickshell --path "$shell_config" \
        ipc call screenshots captured "$1" >/dev/null 2>&1 || true
}

capture_args=()
case "${1:-}" in
    full)
        ;;
    region)
        if ! geometry=$(slurp </dev/null); then
            exit 0
        fi
        [[ -n "$geometry" ]] || exit 0
        capture_args=(-g "$geometry")
        ;;
    *)
        printf 'Usage: hypr-screenshot {full|region}\n' >&2
        exit 2
        ;;
esac

screenshot_directory="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p -- "$screenshot_directory"
screenshot_path=$(mktemp --suffix=.png "$screenshot_directory/Screenshot-$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX")
screenshot_saved=false

remove_incomplete_screenshot() {
    if [[ "$screenshot_saved" == false ]]; then
        rm -f -- "$screenshot_path"
    fi
}
trap remove_incomplete_screenshot EXIT

grim "${capture_args[@]}" "$screenshot_path"
screenshot_saved=true
notify_screenshot_saved "$screenshot_path"
wl-copy --type image/png < "$screenshot_path"
printf '%s\n' "$screenshot_path"
