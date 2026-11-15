eagle_pid=$1

is_white_transparent_background_window() {
  local properties=$1 minimum maximum
  [[ "$properties" =~ minimum\ size:\ ([0-9]+)\ by\ ([0-9]+) ]] || return 1
  minimum="${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
  [[ "$properties" =~ maximum\ size:\ ([0-9]+)\ by\ ([0-9]+) ]] || return 1
  maximum="${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
  [[ "$minimum" == "$maximum" ]] \
    && grep -q '_NET_WM_WINDOW_OPACITY(CARDINAL) = 0$' <<< "$properties" \
    && grep -q 'Client accepts input or input focus: False' <<< "$properties"
}

if [[ -z "${DISPLAY:-}" ]]; then
  exit 0
fi
for ((attempt = 0; attempt < 60; attempt++)); do
  kill -0 "$eagle_pid" 2>/dev/null || exit 0
  while read -r window; do
    [[ -n "$window" ]] || continue
    properties=$(xprop -id "$window" _NET_WM_WINDOW_OPACITY WM_NORMAL_HINTS WM_HINTS 2>/dev/null) || continue
    if is_white_transparent_background_window "$properties"; then
      xdotool windowunmap "$window" || true
      exit 0
    fi
  done < <(xdotool search --all --onlyvisible --pid "$eagle_pid" --class '^eagle\.exe$' 2>/dev/null || true)
  sleep 1
done
