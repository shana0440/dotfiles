import QtQuick
import "../../Theme" as Theme
import "../../Services" as Services

Page {
    id: tasks

    property real now: Date.now()

    title: "Background tasks"
    backLabel: "Settings"

    Timer {
        running: tasks.active
        interval: 3000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            tasks.now = Date.now()
            Services.Mei.loadTasks()
        }
    }

    Group {
        pt: tasks.pt
        Repeater {
            model: Services.Mei.tasks
            TaskRow { pt: tasks.pt; now: tasks.now }
        }
        Text {
            visible: Services.Mei.tasks.length === 0
            width: parent.width
            height: 44 * tasks.pt
            leftPadding: 16 * tasks.pt
            verticalAlignment: Text.AlignVCenter
            text: "No background tasks"
            color: Look.secondaryInk
            font { family: Theme.Fonts.family; pixelSize: 17 * tasks.pt }
        }
    }

    Caption {
        pt: tasks.pt
        note: true
        text: Services.Mei.taskError || "Work " + Services.Mei.name + " is doing or will do later on her own. She reports back in the chat when each one ends."
        color: Services.Mei.taskError ? Look.destructive : Look.secondaryInk
    }
}
