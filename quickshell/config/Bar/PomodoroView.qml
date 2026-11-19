import QtQuick
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Item {
    id: root

    property bool active: false
    readonly property var pomodoro: Services.Pomodoro

    implicitWidth: 480
    implicitHeight: content.implicitHeight + 40

    component PhaseChip: Rectangle {
        id: chip
        property string phase: ""
        readonly property bool current: root.pomodoro.phase === phase

        width: (content.width - 2 * phaseRow.spacing) / 3
        height: 32
        radius: 8
        color: current ? Theme.Colors.foreground
            : chipMouse.containsMouse || activeFocus ? Theme.Colors.surfaceHover : Theme.Colors.surface
        border.width: activeFocus ? 2 : 0
        border.color: Theme.Colors.muted
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label.text
        Keys.onReturnPressed: root.pomodoro.select(phase)
        Keys.onSpacePressed: root.pomodoro.select(phase)

        Text {
            id: label
            anchors.centerIn: parent
            text: root.pomodoro.phases[chip.phase].label
            color: chip.current ? Theme.Colors.background : Theme.Colors.foreground
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 13
        }
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pomodoro.select(chip.phase)
        }
    }

    Column {
        id: content
        x: 20
        y: 20
        width: parent.width - 40
        spacing: 16

        Item {
            width: parent.width
            height: 32

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: "Pomodoro"
                    color: Theme.Colors.foreground
                    font.family: Theme.Fonts.family
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    text: root.pomodoro.phase === "focus"
                        ? "Session " + (root.pomodoro.completed + 1) + " of " + root.pomodoro.sessionsPerRound
                        : root.pomodoro.phase === "longBreak" ? "Round complete"
                        : root.pomodoro.completed + " of " + root.pomodoro.sessionsPerRound + " sessions done"
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 11
                }
            }
        }

        Row {
            id: phaseRow
            spacing: 8

            PhaseChip { phase: "focus" }
            PhaseChip { phase: "shortBreak" }
            PhaseChip { phase: "longBreak" }
        }

        Item {
            width: parent.width
            height: 216

            Canvas {
                id: ring
                anchors.centerIn: parent
                width: 216
                height: 216
                property real fraction: sweep.value
                property color trackColor: Theme.Colors.track
                property color fillColor: root.pomodoro.running ? Theme.Colors.foreground : Theme.Colors.muted
                onFractionChanged: requestPaint()
                onTrackColorChanged: requestPaint()
                onFillColorChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    const c = width / 2
                    const r = c - 4
                    ctx.reset()
                    ctx.lineWidth = 4
                    ctx.lineCap = "round"
                    ctx.strokeStyle = trackColor
                    ctx.beginPath()
                    ctx.arc(c, c, r, 0, Math.PI * 2)
                    ctx.stroke()
                    const left = Math.max(0, Math.min(1, 1 - fraction))
                    if (left <= 0)
                        return
                    ctx.strokeStyle = fillColor
                    ctx.beginPath()
                    ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + left * Math.PI * 2)
                    ctx.stroke()
                }

                Components.Spring {
                    id: sweep
                    to: root.pomodoro.progress
                    precision: 0.0005
                    stiffness: Theme.Motion.stackStiffness
                    damping: Theme.Motion.stackDamping
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.pomodoro.format(root.pomodoro.remaining)
                    color: Theme.Colors.foreground
                    font.family: Theme.Fonts.family
                    font.weight: Font.Light
                    font.pixelSize: 52
                    font.features: ({ "tnum": 1 })
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.pomodoro.running ? root.pomodoro.label
                        : root.pomodoro.progress > 0 ? "Paused" : "Ready"
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 13
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Repeater {
                model: root.pomodoro.sessionsPerRound

                Rectangle {
                    required property int index
                    width: 8
                    height: 8
                    radius: 4
                    color: index < root.pomodoro.completed || root.pomodoro.phase === "longBreak"
                        ? Theme.Colors.foreground : Theme.Colors.track
                }
            }
        }

        Item {
            width: parent.width
            height: 56

            Row {
                anchors.centerIn: parent
                spacing: 28

                Components.IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 40
                    radius: 20
                    iconSize: 20
                    icon: "reset"
                    tooltip: "Reset all sessions"
                    enabled: root.pomodoro.running || root.pomodoro.progress > 0
                        || root.pomodoro.completed > 0 || root.pomodoro.phase !== "focus"
                    onClicked: root.pomodoro.reset()
                }
                Components.IconButton {
                    width: 56
                    height: 56
                    radius: 28
                    iconSize: 24
                    icon: root.pomodoro.running ? "pause" : "play"
                    tooltip: root.pomodoro.running ? "Pause" : "Start"
                    highlighted: true
                    onClicked: root.pomodoro.toggle()
                }
                Components.IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 40
                    radius: 20
                    iconSize: 22
                    icon: "next"
                    tooltip: root.pomodoro.phase === "focus" ? "Skip to break" : "Skip to focus"
                    onClicked: root.pomodoro.skip()
                }
            }
        }
    }
}
