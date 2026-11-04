# Eagle's transparent background BrowserWindow appears white under Wine on some
# compositors. Unmap (never close/kill) only this process's fixed-size, zero-opacity,
# non-focusable window. Hyprland clears skip-taskbar, and HiDPI changes the size.
# Leave the main UI, dialogs, and other Wine apps alone.
if [[ -z "${DISPLAY:-}" ]]; then
  exit 0
fi
for ((attempt = 0; attempt < 60; attempt++)); do
  kill -0 "$1" 2>/dev/null || exit 0
  while read -r window; do
    [[ -n "$window" ]] || continue
    properties=$(xprop -id "$window" _NET_WM_WINDOW_OPACITY WM_NORMAL_HINTS WM_HINTS 2>/dev/null) || continue
    [[ "$properties" =~ minimum\ size:\ ([0-9]+)\ by\ ([0-9]+) ]] || continue
    minimum="${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
    [[ "$properties" =~ maximum\ size:\ ([0-9]+)\ by\ ([0-9]+) ]] || continue
    maximum="${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
    if [[ "$minimum" == "$maximum" ]] \
      && grep -q '_NET_WM_WINDOW_OPACITY(CARDINAL) = 0$' <<< "$properties" \
      && grep -q 'Client accepts input or input focus: False' <<< "$properties"; then
      xdotool windowunmap "$window" || true
      exit 0
    fi
  done < <(xdotool search --all --onlyvisible --pid "$1" --class '^eagle\.exe$' 2>/dev/null || true)
  sleep 1
done
