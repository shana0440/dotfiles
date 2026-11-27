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

    property var walls: []
    readonly property real wallGap: 8
    property real goalX: 0
    property bool bumping: false

    function roomAt(x) {
        let lo = minX
        let hi = maxX
        for (const wall of walls) {
            if (wall.right <= x + 1) lo = Math.max(lo, wall.right + wallGap)
            else if (wall.left >= x + cat.width - 1) hi = Math.min(hi, wall.left - wallGap - cat.width)
        }
        return { lo: lo, hi: Math.max(lo, hi) }
    }
    function freeSpot(x) {
        for (const wall of walls) {
            if (x + cat.width + wallGap <= wall.left || x >= wall.right + wallGap) continue
            const left = wall.left - wallGap - cat.width
            const right = wall.right + wallGap
            if (left < minX) return right
            if (right > maxX) return left
            return x + cat.width / 2 < (wall.left + wall.right) / 2 ? left : right
        }
        return Math.max(minX, Math.min(maxX, x))
    }
    function hopTo(goal) {
        const room = roomAt(cat.x)
        goalX = Math.max(room.lo, Math.min(room.hi, goal))
        bumping = goal < room.lo || goal > room.hi
        if (!hop.running) step()
    }
    function step() {
        const room = roomAt(cat.x)
        goalX = Math.max(room.lo, Math.min(room.hi, goalX))
        const distance = goalX - cat.x
        if (Math.abs(distance) < 1) {
            if (bumping) bonk.restart()
            bumping = false
            return
        }
        facing = distance > 0 ? 1 : -1
        hop.from = cat.x
        hop.target = cat.x + facing * Math.min(Math.abs(distance), 100)
        hop.restart()
    }
    function wander() {
        const room = roomAt(cat.x)
        if (room.hi - room.lo < 1) return
        const direction = Math.random() < (room.hi - cat.x) / (room.hi - room.lo) ? 1 : -1
        hopTo(cat.x + direction * (60 + Math.random() * 300))
    }
    function stepAside() {
        if (flying) return
        const free = freeSpot(cat.x)
        if (Math.abs(free - cat.x) < 1) return
        goalX = free
        bumping = false
        if (!hop.running) step()
    }

    onWallsChanged: stepAside()

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
                jumping: hop.running,
                room: root.roomAt(cat.x),
                walls: root.walls
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
        id: bonk
        NumberAnimation { target: hop; property: "squash"; to: 1.18; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: hop; property: "squash"; to: 1; duration: 220; easing.type: Easing.OutBack }
        PauseAnimation { duration: 260 }
        ScriptAction { script: root.facing = -root.facing }
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
            cat.x = root.freeSpot(skyCat.x)
            spin = 0
            landing.restart()
            root.stepAside()
        }

        onTriggered: {
            const dt = Math.min(frameTime, 0.05)
            const crestY = root.phoneCrestY
            const crestVy = (crestY - lastCrestY) / dt
            lastCrestY = crestY
            const targetX = root.phoneCrestX - skyCat.width / 2
            const overPhone = crestY < root.floorY + cat.sitLine && Math.abs(skyCat.x - targetX) < skyCat.width * 0.6

            if (!root.watching && !contact)
                skyCat.x += (root.freeSpot(skyCat.x) - skyCat.x) * Math.min(1, dt * 8)
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
