# Screen capture commands

The commands behind the [capture UI](../quickshell/config/Capture/README.md)
(`Super+Shift+S`), usable on their own:

```sh
screen-capture-screenshot full               # all screens
screen-capture-screenshot region             # select with the mouse
screen-capture-record full OUTPUT            # a monitor, e.g. DP-1
screen-capture-record region                 # select with the mouse
screen-capture-record stop
```

Screenshots go to `~/Pictures/Screenshots` and the clipboard. Finished recordings
are saved in `~/Videos/Recordings` and copied as files you can paste in Nautilus.
The clipboard holds a reference to the saved MP4, not the video contents.
