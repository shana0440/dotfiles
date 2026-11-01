#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
runner=$(command -v "${QML_TEST_RUNNER:-qmltestrunner}")
qt_prefix=$(dirname -- "$(dirname -- "$(readlink -f -- "$runner")")")
export QML_IMPORT_PATH="${QML_IMPORT_PATH:-$qt_prefix/lib/qt-6/qml}"

mkdir -p "$fixture"/{Bar,Capture,Components,Services,Theme}
cp "$root"/config/Capture/* "$fixture/Capture/"
cp "$root/config/Theme/Colors.qml" "$fixture/Theme/"
printf 'singleton Colors 1.0 Colors.qml\n' > "$fixture/Theme/qmldir"
cp "$root"/tests/tst_*.qml "$fixture/"
cp "$root/config/Bar/SettingsIsland.qml" "$fixture/Bar/"
cp "$root"/config/Components/{MergeableCircle,LoadingSpinner}.qml "$fixture/Components/"
# Stub service state and SVG/tooltip loading; keep the production spinner and island.
cp "$root/tests/fixtures/IconButton.qml" "$fixture/Components/"
cp "$root/tests/fixtures/Capture.qml" "$fixture/Services/"
printf 'singleton Capture 1.0 Capture.qml\n' > "$fixture/Services/qmldir"

for scale in 1 1.5; do
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_SCALE_FACTOR="$scale" \
        "$runner" -input "$fixture"
done
