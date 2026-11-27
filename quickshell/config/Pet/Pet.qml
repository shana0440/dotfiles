import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    signal poked()
    property bool shown: true
    property var phone: null
    property var walls: []
    property real facing: 1
    property bool flying: false

    readonly property var petScreen: Quickshell.screens[0] ?? null
    readonly property bool watching: phone?.opened ?? false
    readonly property bool phoneHere: !!phone && phone.chosenScreen === petScreen
    readonly property real floorY: (petScreen?.height ?? 1080) - cat.sitLine
    readonly property real jumpHeight: 36
    readonly property real headroom: 14
    readonly property real edgeMargin: 24
    readonly property real wallGap: 8
    readonly property bool hovered: touch.containsMouse
    readonly property real minX: edgeMargin
    readonly property real maxX: ground.width - cat.width - edgeMargin
    readonly property var allWalls: watching && phoneHere
        ? walls.concat([{ left: phone.bodyLeft, right: phone.bodyRight, phone: true }])
        : walls

    property real goalX: 0
    property bool bumping: false

    function overPhone(x) {
        const middle = x + cat.width / 2
        return phoneHere && phone.present && middle >= phone.bodyLeft + 4 && middle <= phone.bodyRight - 4
    }
    function phoneSurfaceAt(x) {
        return overPhone(x) ? phone.surfaceAt(x + cat.width / 2) : 1e6
    }
    function liftPending(x) {
        return overPhone(x) && phoneSurfaceAt(x) > floorY + cat.sitLine
    }
    function roomAt(x) {
        let lo = minX
        let hi = maxX
        for (const wall of allWalls) {
            if (wall.right <= x + 1) lo = Math.max(lo, wall.right + wallGap)
            else if (wall.left >= x + cat.width - 1) hi = Math.min(hi, wall.left - wallGap - cat.width)
        }
        return { lo: lo, hi: Math.max(lo, hi) }
    }
    function freeSpot(x) {
        for (const wall of allWalls) {
            if (x + cat.width + wallGap <= wall.left || x >= wall.right + wallGap) continue
            if (wall.phone && liftPending(x)) continue
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

    onAllWallsChanged: stepAside()
    onWatchingChanged: {
        if (watching && phoneHere && !flying && !overPhone(cat.x))
            facing = (phone.bodyLeft + phone.bodyRight) / 2 > cat.x + cat.width / 2 ? 1 : -1
    }

    IpcHandler {
        target: "pet"
        function poke(): void { root.poked() }
        function show(): void { root.shown = true }
        function hide(): void { root.shown = false }
        function jump(direction: string): void { root.hopTo(cat.x + (direction === "left" ? -80 : 80)) }
        function goTo(x: int): void { root.hopTo(x) }
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
                walls: root.allWalls
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
        property real vy: 0
        property real spin: 0
        property real spinRate: 0
        property bool contact: false
        property real lastSurface: 1e6
        property real lastX: -1

        running: root.shown && (root.flying || (root.phoneHere && root.phone.present))

        function liftOff() {
            hopAnim.stop()
            bonk.stop()
            hop.lift = 0
            skyCat.x = cat.x
            skyCat.y = root.floorY
            vy = 0
            spin = 0
            spinRate = 0
            contact = true
            root.flying = true
            landing.restart()
        }

        function settle() {
            root.flying = false
            contact = false
            cat.x = root.freeSpot(skyCat.x)
            spin = 0
            spinRate = 0
            landing.restart()
            root.stepAside()
        }

        onTriggered: {
            const dt = Math.min(frameTime, 0.05)
            if (!root.flying) {
                const surface = root.phoneSurfaceAt(cat.x)
                const floorLine = root.floorY + cat.sitLine
                if (lastX === cat.x && lastSurface > floorLine && surface <= floorLine) liftOff()
                lastSurface = surface
                lastX = cat.x
                return
            }

            vy += gravity * dt
            if (contact) {
                const seatY = root.phoneSurfaceAt(skyCat.x) - skyCat.sitLine
                if (seatY < root.floorY && skyCat.y + vy * dt >= seatY) {
                    vy = Math.max((seatY - skyCat.y) / dt, -launchCap)
                    skyCat.y = seatY
                    spin = root.phone.tiltAngle
                    return
                }
                contact = false
                if (vy < -600) spinRate = 360 * root.facing / (2 * -vy / gravity)
            }

            skyCat.y += vy * dt
            spin += spinRate * dt
            if (!root.watching)
                skyCat.x += (root.freeSpot(skyCat.x) - skyCat.x) * Math.min(1, dt * 8)

            const surface = root.phoneSurfaceAt(skyCat.x)
            const wasAbove = skyCat.y + skyCat.sitLine - vy * dt <= lastSurface + 2
            lastSurface = surface
            if (wasAbove && skyCat.y + skyCat.sitLine >= surface) {
                if (spinRate !== 0) landing.restart()
                contact = true
                spinRate = 0
                skyCat.y = surface - skyCat.sitLine
                vy = 0
                return
            }

            if (skyCat.y >= root.floorY) {
                skyCat.y = root.floorY
                settle()
                lastSurface = root.phoneSurfaceAt(cat.x)
                lastX = cat.x
            }
        }
    }
}
