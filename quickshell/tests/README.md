# Quickshell tests

```sh
python3 -m unittest discover -s quickshell/scripts -q
python3 -m unittest discover -s quickshell/tests -q
node --test quickshell/tests/region_geometry.test.mjs
bash quickshell/tests/run-qml-tests.sh
```

The QML tests require Qt 6's `qmltestrunner` (`qt6.qtdeclarative`). Set
`QML_TEST_RUNNER` to its full path if it is not on `PATH`.
They exercise the production region editor, size label, settings island, spinner,
and workspace buttons at 100% and 150% scaling. Quickshell service state, the
Hyprland dispatcher boundary, and the settings button's SVG/tooltip loader are
stubbed. All tests run offscreen and do not
capture the desktop or start a recorder.

The lifecycle tests run real Quickshell components offscreen with shared
runtime/DBus isolation and fake helpers. The Wi-Fi test verifies that a successful
connection is followed by a fresh network list without accessing NetworkManager.
The screenshot queue tests check that accepted requests run in order and that
capture failures or missing executables do not block later requests.
The capture test checks screenshot feedback
before helper IPC, success/failure cleanup, and an uninterrupted recording
outline across deliberately stale status responses. It loads the full production
configuration tree, repeats the workflow after atomic service-file replacements
and soft reloads, and verifies that the capture service and screenshot IPC remain
available in every generation.
