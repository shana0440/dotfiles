set -euo pipefail

slurp_without_rectangle_suggestions() {
    slurp </dev/null
}

capture_args=()
case "${1:-}" in
    full)
        ;;
    region)
        geometry="${2:-}"
        if [[ -z "$geometry" ]]; then
                if ! geometry=$(slurp_without_rectangle_suggestions); then
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
        printf 'Usage: screen-capture-screenshot {full|region [GEOMETRY]}\n' >&2
        exit 2
        ;;
esac

screenshot_directory="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p -- "$screenshot_directory"
screenshot_path=$(mktemp --suffix=.png "$screenshot_directory/Screenshot-$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX")
screenshot_saved=false

remove_unsaved() {
    if [[ "$screenshot_saved" == false ]]; then
        rm -f -- "$screenshot_path"
    fi
}
trap remove_unsaved EXIT

fastest_lossless_png_compression=1
grim -l "$fastest_lossless_png_compression" "${capture_args[@]}" "$screenshot_path"
screenshot_saved=true
printf '%s\n' "$screenshot_path"
screen-capture-notify screenshot "$screenshot_path" >/dev/null 2>&1 &
wl-copy --type image/png < "$screenshot_path"
