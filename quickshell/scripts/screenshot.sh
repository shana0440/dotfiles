set -euo pipefail

notify_screenshot_event() {
    local shell_config="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
    # Saving and clipboard delivery must work while Quickshell is unavailable.
    timeout 1s quickshell --path "$shell_config" \
        ipc call screenshots "$1" "$2" >/dev/null 2>&1 || true
}

capture_args=()
case "${1:-}" in
    full)
        ;;
    region)
        geometry="${2:-}"
        if [[ -z "$geometry" ]]; then
            if timeout 1s quickshell --path "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell" \
                ipc call capture selectRegion screenshot >/dev/null 2>&1; then
                exit 0
            fi
            if ! geometry=$(slurp </dev/null); then
                exit 0
            fi
            [[ -n "$geometry" ]] || exit 0
        fi
        if [[ ! "$geometry" =~ ^-?[0-9]+,-?[0-9]+\ [1-9][0-9]*x[1-9][0-9]*$ ]]; then
            printf 'Invalid screenshot geometry.\n' >&2
            exit 2
        fi
        capture_args=(-g "$geometry")
        ;;
    *)
        printf 'Usage: hypr-screenshot {full|region [GEOMETRY]}\n' >&2
        exit 2
        ;;
esac

screenshot_directory="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p -- "$screenshot_directory"
screenshot_path=$(mktemp --suffix=.png "$screenshot_directory/Screenshot-$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX")
screenshot_saved=false

finish_screenshot() {
    notify_screenshot_event finished "$screenshot_path"
    if [[ "$screenshot_saved" == false ]]; then
        rm -f -- "$screenshot_path"
    fi
}
trap finish_screenshot EXIT
notify_screenshot_event started "$screenshot_path"

# Favor capture latency over PNG file size; compression remains lossless.
grim -l 1 "${capture_args[@]}" "$screenshot_path"
screenshot_saved=true
printf '%s\n' "$screenshot_path"
notify_screenshot_event captured "$screenshot_path"
wl-copy --type image/png < "$screenshot_path"
