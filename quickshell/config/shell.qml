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
    Dock { id: dock }
    WallpaperTransition {}
    WallpaperPicker {}
    ScreenCapture {}
    MissionControl { id: missionControl }
    WindowSwitcher {}
    Phone { id: phone }
    Pet {
        phone: phone
        walls: dock.visible ? [{ left: dock.wallLeft, right: dock.wallRight }] : []
        onPoked: phone.toggle()
    }
    Lock {}
}
