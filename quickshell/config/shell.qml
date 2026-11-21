import Quickshell
import "Capture"
import "Dock"
import "Lock"
import "MissionControl"
import "Phone"
import "Wallpaper"
import "Services" as Services

ShellRoot {
    Services.SavedTheme {}
    Bar {}
    Dock {}
    WallpaperTransition {}
    WallpaperPicker {}
    ScreenCapture {}
    MissionControl {}
    Phone {}
    Lock {}
}
