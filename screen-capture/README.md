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

Screenshots go to `~/Pictures/Screenshots` and the clipboard; recordings to
`~/Videos/Recordings`.
