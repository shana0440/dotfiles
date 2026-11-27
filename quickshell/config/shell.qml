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
        phoneScreen: phone.chosenScreen
        phoneCrestX: phone.crestX
        phoneCrestY: phone.crestY
        phoneCrestAngle: phone.crestAngle
        onPoked: phone.toggle()
    }
    Lock {}
}
