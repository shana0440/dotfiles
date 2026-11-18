import QtQuick
import "../../Theme" as Theme
import "../../Services" as Services

Page {
    id: schedules

    title: "Schedules"
    backLabel: "Settings"
    onActiveChanged: if (active) Services.Mei.loadSchedules()

    Group {
        pt: schedules.pt
        Repeater {
            model: Services.Mei.schedules
            ScheduleRow { pt: schedules.pt }
        }
        Text {
            visible: Services.Mei.schedules.length === 0
            width: parent.width
            height: 44 * schedules.pt
            leftPadding: 16 * schedules.pt
            verticalAlignment: Text.AlignVCenter
            text: "No schedules"
            color: Look.secondaryInk
            font { family: Theme.Fonts.family; pixelSize: 17 * schedules.pt }
        }
    }

    Caption {
        pt: schedules.pt
        note: true
        text: Services.Mei.scheduleError || "A turned-off schedule stays in config.toml but never runs on its own. Removing one keeps its script or prompt."
        color: Services.Mei.scheduleError ? Look.destructive : Look.secondaryInk
    }
}
