import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Theme" as Theme

PanelWindow {
    id: root

    signal poked()
    property bool shown: true
    property bool watching: false
    property real facing: 1

    readonly property real drawingScale: 0.32
    readonly property real peekHeight: 72
    readonly property real jumpHeight: 36
    readonly property real headroom: 14
    readonly property real edgeMargin: 24
    readonly property bool hovered: touch.containsMouse
    readonly property real minX: edgeMargin
    readonly property real maxX: width - cat.width - edgeMargin

    property real goalX: 0
    property real watchedLeft: 0
    property real watchedRight: 0
    readonly property real watchedCenter: (watchedLeft + watchedRight) / 2

    function hopTo(goal) {
        goalX = Math.max(minX, Math.min(maxX, goal))
        if (!hop.running) step()
    }
    function step() {
        const distance = goalX - cat.x
        if (Math.abs(distance) < 1) {
            if (watching) faceWatched()
            return
        }
        facing = distance > 0 ? 1 : -1
        hop.from = cat.x
        hop.target = cat.x + facing * Math.min(Math.abs(distance), 100)
        hop.restart()
    }
    function wander() {
        const direction = Math.random() < (maxX - cat.x) / (maxX - minX) ? 1 : -1
        hopTo(cat.x + direction * (60 + Math.random() * 300))
    }
    function faceWatched() {
        facing = watchedCenter > cat.x + cat.width / 2 ? 1 : -1
    }
    function besideWatched() {
        const gap = 16
        if (cat.x + cat.width < watchedLeft - gap || cat.x > watchedRight + gap) return cat.x
        const right = watchedRight + gap
        const left = watchedLeft - gap - cat.width
        if (right > maxX) return left
        if (left < minX) return right
        return cat.x + cat.width / 2 > watchedCenter ? right : left
    }

    onWatchingChanged: if (watching) hopTo(besideWatched())
    onWatchedCenterChanged: if (watching) hopTo(besideWatched())

    screen: Quickshell.screens[0] ?? null
    visible: shown
    anchors { bottom: true; left: true; right: true }
    implicitHeight: peekHeight + jumpHeight + headroom
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: cat }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-pet"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    IpcHandler {
        target: "pet"
        function poke(): void { root.poked() }
        function show(): void { root.shown = true }
        function hide(): void { root.shown = false }
        function jump(direction: string): void { root.hopTo(cat.x + (direction === "left" ? -80 : 80)) }
        function state(): string {
            return JSON.stringify({
                shown: root.shown,
                watching: root.watching,
                x: Math.round(cat.x),
                facing: root.facing > 0 ? "right" : "left",
                jumping: hop.running
            })
        }
    }

    Timer {
        id: roam
        interval: 2000
        repeat: true
        running: root.visible && !root.hovered && !root.watching && !hop.running
        onTriggered: {
            interval = 2000 + Math.random() * 5000
            root.wander()
        }
    }

    QtObject {
        id: hop
        property real from: 0
        property real target: 0
        property real lift: 0
        property real squash: 1
        readonly property bool running: hopAnim.running
        function restart() { hopAnim.restart() }
    }

    SequentialAnimation {
        id: hopAnim
        NumberAnimation { target: hop; property: "squash"; to: 0.86; duration: 90; easing.type: Easing.OutQuad }
        ParallelAnimation {
            NumberAnimation { target: cat; property: "x"; from: hop.from; to: hop.target; duration: 420; easing.type: Easing.InOutSine }
            NumberAnimation { target: hop; property: "squash"; to: 1.06; duration: 160; easing.type: Easing.OutQuad }
            SequentialAnimation {
                NumberAnimation { target: hop; property: "lift"; to: root.jumpHeight; duration: 210; easing.type: Easing.OutQuad }
                NumberAnimation { target: hop; property: "lift"; to: 0; duration: 210; easing.type: Easing.InQuad }
            }
        }
        NumberAnimation { target: hop; property: "squash"; to: 0.84; duration: 70; easing.type: Easing.OutQuad }
        NumberAnimation { target: hop; property: "squash"; to: 1; duration: 160; easing.type: Easing.OutBack }
        onFinished: {
            if (root.watching || !root.hovered) root.step()
        }
    }

    Item {
        id: cat
        property real perch: root.hovered && !hop.running ? -8 : touch.pressed ? 6 : 0
        Behavior on perch { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
        x: root.width - width - 40
        y: root.height - root.peekHeight + perch - hop.lift
        width: 380 * root.drawingScale
        height: 235 * root.drawingScale

        Item {
            anchors.fill: parent
            transform: [
                Scale { origin.x: cat.width / 2; xScale: root.facing },
                Scale { origin.x: cat.width / 2; origin.y: root.peekHeight; yScale: hop.squash; xScale: 2 - hop.squash }
            ]

            Item {
                id: drawing
                width: 380
                height: 235
                scale: root.drawingScale
                transformOrigin: Item.TopLeft

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: Theme.Colors.background
                        strokeWidth: 20
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathSvg { id: tail; path: "M 80 222 Q 45 200 20 210" }
                    }
                    ShapePath {
                        strokeWidth: -1
                        fillColor: Theme.Colors.background
                        PathSvg { path: "M 52 180 A 160 112 0 1 1 372 180 A 160 112 0 1 1 52 180 Z" }
                    }
                    ShapePath {
                        strokeWidth: -1
                        fillColor: Theme.Colors.background
                        PathSvg { path: "M 100 104 L 120 34 Q 128 10 148 24 L 204 74 Z" }
                    }
                    ShapePath {
                        strokeWidth: -1
                        fillColor: Theme.Colors.background
                        PathSvg { path: "M 226 72 L 278 28 Q 298 12 304 36 L 322 108 Z" }
                    }
                }

                Row {
                    id: eyes
                    x: 194
                    y: 128
                    spacing: 50

                    Repeater {
                        model: 2
                        Rectangle {
                            width: 24
                            height: 46
                            radius: 12
                            color: "#ffffff"
                            transform: Scale { origin.y: 23; yScale: blink.lid }
                        }
                    }
                }
            }
        }

        MouseArea {
            id: touch
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.poked()
        }
    }

    QtObject {
        id: blink
        property real lid: 1
    }

    SequentialAnimation {
        running: root.visible
        loops: Animation.Infinite
        PauseAnimation { duration: 2600 + Math.random() * 2400 }
        NumberAnimation { target: blink; property: "lid"; to: 0.1; duration: 70 }
        NumberAnimation { target: blink; property: "lid"; to: 1; duration: 110 }
    }

    SequentialAnimation {
        running: root.visible && root.hovered
        loops: Animation.Infinite
        alwaysRunToEnd: true
        PropertyAction { target: tail; property: "path"; value: "M 80 222 Q 45 186 26 176" }
        PauseAnimation { duration: 220 }
        PropertyAction { target: tail; property: "path"; value: "M 80 222 Q 45 200 20 210" }
        PauseAnimation { duration: 220 }
    }
}
