set -euo pipefail
umask 077

case "${1:-}" in
    full|region) mode="$1" ;;
    *) exit 2 ;;
esac

# systemd runs this on success and failure, independently of the application UI.
rm -f -- "${XDG_RUNTIME_DIR:?}/screen-capture-record-$mode.path"
