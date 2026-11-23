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
    Bar {
        onMissionControlRequested: missionControl.show()
    }
    Dock {}
    WallpaperTransition {}
    WallpaperPicker {}
    ScreenCapture {}
    MissionControl { id: missionControl }
    Phone {}
    Lock {}
}
