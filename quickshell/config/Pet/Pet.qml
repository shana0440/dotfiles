import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    signal poked()
    property bool shown: true
    property bool watching: false
    property var phoneScreen: null
    property real phoneCrestX: 0
    property real phoneCrestY: 1e6
    property real phoneCrestAngle: 0
    property real facing: 1
    property bool flying: false

    readonly property var petScreen: Quickshell.screens[0] ?? null
    readonly property real floorY: (petScreen?.height ?? 1080) - cat.sitLine
    readonly property real jumpHeight: 36
    readonly property real headroom: 14
    readonly property real edgeMargin: 24
    readonly property bool hovered: touch.containsMouse
    readonly property real minX: edgeMargin
    readonly property real maxX: ground.width - cat.width - edgeMargin

    property real goalX: 0

    function hopTo(goal) {
        goalX = Math.max(minX, Math.min(maxX, goal))
        if (!hop.running) step()
    }
    function step() {
        const distance = goalX - cat.x
        if (Math.abs(distance) < 1) return
        facing = distance > 0 ? 1 : -1
        hop.from = cat.x
        hop.target = cat.x + facing * Math.min(Math.abs(distance), 100)
        hop.restart()
    }
    function wander() {
        const direction = Math.random() < (maxX - cat.x) / (maxX - minX) ? 1 : -1
        hopTo(cat.x + direction * (60 + Math.random() * 300))
    }

    onWatchingChanged: {
        if (watching && shown && !flying && phoneScreen === petScreen)
            flight.takeOff()
    }

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
                flying: root.flying,
                riding: flight.contact,
                x: Math.round(root.flying ? skyCat.x : cat.x),
                y: Math.round(root.flying ? skyCat.y : root.floorY),
                facing: root.facing > 0 ? "right" : "left",
                jumping: hop.running
            })
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: ground.visible && !root.flying && !root.hovered && !root.watching && !hop.running
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
        onFinished: if (!root.hovered && !root.flying) root.step()
    }

    SequentialAnimation {
        id: landing
        NumberAnimation { target: hop; property: "squash"; to: 0.78; duration: 80; easing.type: Easing.OutQuad }
        NumberAnimation { target: hop; property: "squash"; to: 1; duration: 260; easing.type: Easing.OutBack }
    }

    PanelWindow {
        id: ground
        screen: root.petScreen
        visible: root.shown
        anchors { bottom: true; left: true; right: true }
        implicitHeight: cat.sitLine + root.jumpHeight + root.headroom
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region { item: root.flying ? nothing : cat }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-pet"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Item { id: nothing }

        Cat {
            id: cat
            property real perch: root.hovered && !hop.running ? -8 : touch.pressed ? 6 : 0
            Behavior on perch { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            visible: !root.flying
            x: ground.width - width - 40
            y: ground.height - sitLine + perch - hop.lift
            facing: root.facing
            squash: hop.squash
            wagging: root.hovered

            MouseArea {
                id: touch
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.poked()
            }
        }
    }

    PanelWindow {
        id: sky
        screen: root.petScreen
        visible: root.shown && root.flying
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-pet-sky"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Cat {
            id: skyCat
            facing: root.facing
            squash: hop.squash
            wagging: flight.contact
            spin: flight.spin
        }
    }

    FrameAnimation {
        id: flight
        readonly property real gravity: 3200
        readonly property real launchCap: 1050
        readonly property real hopSpeed: 900
        property real vy: 0
        property real spin: 0
        property real spinRate: 0
        property bool contact: false
        property real lastCrestY: 1e6

        running: root.flying

        function takeOff() {
            hopAnim.stop()
            hop.lift = 0
            skyCat.x = cat.x
            skyCat.y = root.floorY
            vy = -hopSpeed
            spin = 0
            spinRate = 0
            contact = false
            lastCrestY = root.phoneCrestY
            root.flying = true
        }

        function settle() {
            root.flying = false
            cat.x = Math.max(root.minX, Math.min(root.maxX, skyCat.x))
            spin = 0
            landing.restart()
        }

        onTriggered: {
            const dt = Math.min(frameTime, 0.05)
            const crestY = root.phoneCrestY
            const crestVy = (crestY - lastCrestY) / dt
            lastCrestY = crestY
            const targetX = root.phoneCrestX - skyCat.width / 2
            const overPhone = crestY < root.floorY + cat.sitLine && Math.abs(skyCat.x - targetX) < skyCat.width * 0.6

            if (root.watching) {
                skyCat.x += (targetX - skyCat.x) * Math.min(1, dt * 10)
                root.facing = targetX > skyCat.x + 1 ? 1 : targetX < skyCat.x - 1 ? -1 : root.facing
            }

            vy += gravity * dt
            skyCat.y += vy * dt
            spin += spinRate * dt

            const seat = crestY - skyCat.sitLine
            if (overPhone && skyCat.y >= seat && vy >= crestVy) {
                if (!contact && spinRate !== 0) landing.restart()
                skyCat.y = seat
                vy = Math.max(crestVy, -launchCap)
                contact = true
                spin = root.phoneCrestAngle
                spinRate = 0
            } else if (contact) {
                contact = false
                if (vy < -600) spinRate = 360 * root.facing / (2 * -vy / gravity)
            }

            if (!contact && skyCat.y >= root.floorY) {
                skyCat.y = root.floorY
                spinRate = 0
                spin = 0
                if (root.watching) {
                    vy = -hopSpeed
                } else {
                    vy = 0
                    settle()
                }
            }
        }
    }
}
