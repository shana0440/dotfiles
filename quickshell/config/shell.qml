import Quickshell
import "Capture"
import "Lock"
import "MissionControl"
import "Wallpaper"
import "Services" as Services

ShellRoot {
    Services.SavedTheme {}
    Bar {}
    WallpaperTransition {}
    WallpaperPicker {}
    ScreenCapture {}
    MissionControl {}
    Lock {}
}
