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
        watching: phone.opened
        phoneScreen: phone.chosenScreen
        walls: dock.visible ? [{ left: dock.wallLeft, right: dock.wallRight }] : []
        phoneCrestX: phone.crestX
        phoneCrestY: phone.crestY
        phoneCrestAngle: phone.crestAngle
        onPoked: phone.toggle()
    }
    Lock {}
}
