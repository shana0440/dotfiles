import Quickshell
import "Capture"
import "Lock"
import "MissionControl"
import "Phone"
import "Wallpaper"
import "Services" as Services

ShellRoot {
    Services.SavedTheme {}
    Bar {}
    WallpaperTransition {}
    WallpaperPicker {}
    ScreenCapture {}
    MissionControl {}
    Phone {}
    Lock {}
}
