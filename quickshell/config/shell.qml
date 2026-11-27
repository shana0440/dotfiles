import Quickshell
import "Capture"
import "Dock"
import "Lock"
import "MissionControl"
import "Pet"
import "Phone"
import "Wallpaper"
import "WindowSwitcher"
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
    WindowSwitcher {}
    Phone { id: phone }
    Pet {
        watching: phone.opened
        watchedLeft: phone.bodyLeft
        watchedRight: phone.bodyRight
        onPoked: phone.toggle()
    }
    Lock {}
}
