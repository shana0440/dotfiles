import QtQuick
import QtQuick.Effects
import "../Theme" as Theme

// The authentication card: the user, the password field and the power actions.
// It only reports what was asked for; the wrapper (SDDM or the lock) does the work.
Rectangle {
    id: root

    property string mode: "lock"
    property string userName: ""
    property string hostName: ""
    property string authState: "idle"
    property string message: ""
    property bool capsLock: false
    // Login only: the session to start, cycled with nextSession().
    property string sessionName: ""

    signal submit(string password)
    // Typing after a failure; the wrapper returns to idle.
    signal edited()
    signal nextSession()
    signal suspend()
    signal reboot()
    signal powerOff()

    function focusInput() { password.forceActiveFocus() }
    function clear() { password.text = "" }
    readonly property bool typing: password.text.length > 0

    readonly property string displayName: userName.length
        ? userName.charAt(0).toUpperCase() + userName.slice(1) : ""
    readonly property color statusColor: authState === "denied" ? Theme.Colors.error
        : authState === "granted" ? Theme.Colors.success
        : Theme.Colors.muted
    readonly property string statusText: ({
        idle: "Locked", busy: "Checking", denied: "Denied", granted: "Granted"
    })[authState] ?? "Locked"

    implicitWidth: 440
    implicitHeight: column.implicitHeight + 64
    radius: 20
    color: Theme.Colors.panel
    border.width: 1
    border.color: Theme.Colors.edge

    RectangularShadow {
        z: -1
        anchors.fill: parent
        radius: root.radius
        offset.y: 8
        blur: 32
        spread: -8
        color: Theme.Colors.shadow
    }

    // A wrong password shakes the card sideways.
    transform: Translate { id: shift }
    SequentialAnimation {
        id: shake
        NumberAnimation { target: shift; property: "x"; to: -10; duration: 50 }
        NumberAnimation { target: shift; property: "x"; to: 9; duration: 70 }
        NumberAnimation { target: shift; property: "x"; to: -6; duration: 70 }
        NumberAnimation { target: shift; property: "x"; to: 3; duration: 70 }
        NumberAnimation { target: shift; property: "x"; to: 0; duration: 60 }
    }
    onAuthStateChanged: {
        if (authState === "denied") {
            shake.restart()
            clear()
        }
        focusInput()
    }

    component RoundButton: Rectangle {
        id: button
        property string glyph
        property string label
        property color tint: Theme.Colors.foreground
        signal clicked()

        width: 40
        height: 40
        radius: 20
        color: area.containsMouse || activeFocus ? Theme.Colors.highlight : Theme.Colors.transparent
        border.width: 1
        border.color: Theme.Colors.ring
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label
        Keys.onReturnPressed: clicked()
        Keys.onSpacePressed: clicked()

        Glyph {
            anchors.centerIn: parent
            width: 17
            height: 17
            name: button.glyph
            color: area.containsMouse ? button.tint : Theme.Colors.foreground
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    Column {
        id: column
        x: 32
        y: 32
        width: parent.width - 64
        spacing: 0

        // Header: section label and the current state.
        Item {
            width: parent.width
            height: 28

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Text {
                    text: "01"
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.mono
                    font.pixelSize: 13
                }
                Text {
                    text: "//"
                    color: Theme.Colors.edge
                    font.family: Theme.Fonts.mono
                    font.pixelSize: 13
                }
                Text {
                    text: "Authentication"
                    color: Theme.Colors.foreground
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 14
                    font.letterSpacing: 1.5
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: status.implicitWidth + 20
                height: 24
                radius: 12
                color: Theme.Colors.surface
                border.width: 1
                border.color: root.authState === "idle" ? Theme.Colors.ring : root.statusColor
                Behavior on border.color { ColorAnimation { duration: 180 } }

                Text {
                    id: status
                    anchors.centerIn: parent
                    text: root.statusText
                    color: root.authState === "idle" ? Theme.Colors.muted : root.statusColor
                    font.family: Theme.Fonts.mono
                    font.pixelSize: 11
                    font.letterSpacing: 1
                }
            }
        }

        Item { width: 1; height: 14 }

        // Divider with a short bright segment at the start.
        Item {
            width: parent.width
            height: 2
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: Theme.Colors.ring }
            Rectangle { width: 48; height: 2; radius: 1; color: Theme.Colors.foreground }
        }

        Item { width: 1; height: 28 }

        AvatarRing {
            anchors.horizontalCenter: parent.horizontalCenter
            initial: root.displayName.charAt(0) || "?"
            authState: root.authState
        }

        Item { width: 1; height: 16 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.displayName
            color: Theme.Colors.foreground
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 26
        }

        Item { width: 1; height: 6 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            textFormat: Text.StyledText
            text: "<font color='" + Theme.Colors.foreground + "'>" + root.userName + "@" + root.hostName
                + "</font> ~ ❯ " + (root.mode === "login"
                    ? "login --session " + root.sessionName.toLowerCase().split(" ")[0]
                    : "unlock")
            color: Theme.Colors.muted
            font.family: Theme.Fonts.mono
            font.pixelSize: 13
        }

        Item { width: 1; height: 28 }

        // Password field.
        Rectangle {
            id: field
            width: parent.width
            height: 54
            radius: 14
            color: Theme.Colors.surface
            border.width: password.activeFocus ? 2 : 1
            border.color: root.authState === "denied" ? Theme.Colors.error
                : password.activeFocus ? Theme.Colors.foreground : Theme.Colors.edge
            Behavior on border.color { ColorAnimation { duration: 180 } }

            Glyph {
                id: lockGlyph
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 17
                height: 17
                name: "lock-keyhole"
                color: Theme.Colors.muted
            }

            TextInput {
                id: password
                anchors.left: lockGlyph.right
                anchors.leftMargin: 14
                anchors.right: submitButton.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: Theme.Colors.foreground
                selectionColor: Theme.Colors.track
                selectedTextColor: Theme.Colors.foreground
                font.family: Theme.Fonts.mono
                font.pixelSize: 17
                font.letterSpacing: 3
                clip: true
                focus: true
                // Read-only rather than disabled: disabling drops the keyboard focus.
                readOnly: root.authState === "busy" || root.authState === "granted"
                onAccepted: if (text.length && !readOnly) root.submit(text)
                onTextEdited: root.edited()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !password.text.length
                    text: "Password"
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.pixelSize: 16
                }
            }

            // Ding's primary action: filled with the foreground, glyph inverted.
            Rectangle {
                id: submitButton
                anchors.right: parent.right
                anchors.rightMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: 10
                color: submitArea.containsMouse ? Qt.tint(Theme.Colors.foreground, "#2e0c0c0d") : Theme.Colors.foreground
                opacity: password.text.length ? 1 : 0.35
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Glyph {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    name: "arrow-right"
                    color: Theme.Colors.background
                }

                MouseArea {
                    id: submitArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: password.accepted()
                }
            }
        }

        Item { width: 1; height: 12 }

        // Hint line: the error, Caps Lock, or how to continue.
        Text {
            x: 4
            width: parent.width - 8
            elide: Text.ElideRight
            text: root.authState === "denied" ? (root.message || "Wrong password")
                : root.authState === "busy" ? "Checking…"
                : root.authState === "granted" ? (root.mode === "login" ? "Starting session…" : "Unlocking…")
                : root.capsLock ? "Caps Lock is on"
                : "↵  Enter to " + (root.mode === "login" ? "log in" : "unlock")
            color: root.authState === "denied" ? Theme.Colors.error
                : root.capsLock ? Theme.Colors.warning
                : Theme.Colors.muted
            font.family: Theme.Fonts.mono
            font.pixelSize: 12
        }

        Item { width: 1; height: 32 }

        Rectangle { width: parent.width; height: 1; color: Theme.Colors.ring }

        Item { width: 1; height: 20 }

        // Session (login only) and power actions.
        Item {
            width: parent.width
            height: 40

            Rectangle {
                visible: root.mode === "login"
                width: Math.min(200, sessionText.implicitWidth + 40)
                height: 40
                radius: 20
                color: sessionArea.containsMouse || activeFocus ? Theme.Colors.highlight : Theme.Colors.transparent
                border.width: 1
                border.color: Theme.Colors.ring
                activeFocusOnTab: visible
                Keys.onReturnPressed: root.nextSession()
                Keys.onSpacePressed: root.nextSession()

                Text {
                    id: sessionText
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, 160)
                    elide: Text.ElideRight
                    text: root.sessionName
                    color: Theme.Colors.foreground
                    font.family: Theme.Fonts.family
                    font.pixelSize: 13
                }

                MouseArea {
                    id: sessionArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.nextSession()
                }
            }

            Row {
                anchors.right: parent.right
                spacing: 12
                RoundButton { glyph: "moon"; label: "Suspend"; onClicked: root.suspend() }
                RoundButton { glyph: "rotate-cw"; label: "Restart"; tint: Theme.Colors.warning; onClicked: root.reboot() }
                RoundButton { glyph: "power"; label: "Shut down"; tint: Theme.Colors.error; onClicked: root.powerOff() }
            }
        }
    }
}
