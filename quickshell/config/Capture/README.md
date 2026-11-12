# Screen capture UI

Toolbar and selectors for screenshots and recordings, part of the Quickshell
bar. The work is done by the `screen-capture-*` commands from the
`screen-capture/` module; this folder only owns the look and interaction.
State lives in `Services/Capture.qml`, which the bar's recording indicator
(`Bar/RecordingView.qml`) also reads.

## Opening

Super+Shift+S, or:

```sh
quickshell --path ~/.config/quickshell ipc call capture open
quickshell --path ~/.config/quickshell ipc call capture close
quickshell --path ~/.config/quickshell ipc call capture stop
quickshell --path ~/.config/quickshell ipc call capture status
```

`status` returns `recording`, `mode`, `startedAtMs`, `geometry`, `window` and
`preview` (whether a frozen frame is shown).

Opening freezes the desktop first (one non-live `ScreencopyView` per output,
straight from GPU memory), then shows a bottom-centred toolbar over the dimmed
frame. Applications keep running; screenshots are saved from that frame, so
they never include the toolbar, shade or selection outline.

## Modes

| Key | Mode |
| --- | --- |
| 1 | Screenshot all screens |
| 2 | Screenshot a window |
| 3 | Screenshot a region |
| 4 | Record a screen |
| 5 | Record a window |
| 6 | Record a region |

Recording modes carry a small dot. The action button reads **Capture** or
**Record**; Enter does the same and Esc dismisses the toolbar and releases the
frozen frame.

- **Window**: point at a window and it is cut out of the shade with a dashed
  outline; click to lock it. Geometry and stacking are frozen at launch.
  "Loading windows…" shows until `screen-capture-snapshot freeze` reports.
- **Region**: drag to select, then move or resize with the handles. Selecting on
  another screen moves the toolbar there; full-screen recording uses the
  toolbar's screen.

## Recording

Recording returns to the live desktop before the recorder starts. While it
runs, the bar's center island shows the elapsed time and Stop; reopening the
toolbar shows only **Stop · Ns**, and Esc closes it without stopping. Region
recordings keep the outside shaded and outlined; window recordings outline the
window and follow it (Hyprland is polled ~10 times a second) and hide the
outline while it is unmapped or on a hidden workspace. The outline is only on
screen, never in the video.

The bar learns about recordings started or stopped elsewhere from the
`screenCapture changed` IPC ping and a 5-second status poll (for recordings that
end on their own).

## Layers and input

The frozen selector and recording shade (`quickshell-capture-region`) sit on the
Top layer, below the toolbar (`quickshell-capture-toolbar`) and the recording
bar on Overlay, so the shade never covers Stop. Hyprland routes pointer input to
exclusive layer surfaces while one is open: the selector becomes exclusive while
the frame is still capturing, so the toolbar, mapped later, wins pointer input.
Shortcuts use application scope so Enter/Esc/number keys keep working after a
drag focuses the selector. The shade is click-through while recording.

Colours come from `Theme/Colors.qml` (`panel`, `scrim`, `accent`, …); mode
buttons are `Components/IconButton` with Lucide icons.
