import QtQuick
import Quickshell.Services.Pipewire
import "../Theme" as Theme
import "../Components" as Components
import "../Services" as Services

Item {
    id: root

    property bool active: false
    property int maximumHeight: 560
    property string page: ""
    property string shownPage: ""
    readonly property bool pickingInput: shownPage === "input"

    onPageChanged: if (page) shownPage = page
    onActiveChanged: page = ""

    function navigateBack() {
        page = ""
    }

    function navigateForward() {
        page = shownPage
    }

    width: 360
    height: page ? devicePage.implicitHeight : home.implicitHeight + 40
    clip: true

    Components.Spring {
        id: pageSpring
        to: root.page ? 1 : 0
        stiffness: Theme.Motion.stackStiffness
        damping: Theme.Motion.stackDamping
        precision: 0.002
    }

    MouseArea {
        z: 1
        anchors.fill: parent
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        onPressed: mouse => {
            if (mouse.button === Qt.BackButton)
                root.navigateBack()
            else
                root.navigateForward()
        }
    }

    Column {
        id: home
        x: 20 - 24 * pageSpring.value
        y: 20
        width: parent.width - 40
        spacing: 4
        opacity: 1 - pageSpring.value
        visible: opacity > 0
        enabled: !root.page

        Text {
            bottomPadding: 6
            text: "Sound"
            color: Theme.Colors.foreground
            font.family: Theme.Fonts.family
            font.pixelSize: 16
            font.bold: true
        }

        SoundLevel {
            node: Services.Sound.sink
            icon: "speaker"
            mutedIcon: "speakerMuted"
            what: "output"
            label: Services.Sound.label(node) || "No output device"
            openable: true
            onOpened: root.page = "output"
        }
        SoundLevel {
            node: Services.Sound.source
            icon: "microphone"
            mutedIcon: "microphoneMuted"
            what: "input"
            label: Services.Sound.label(node) || "No input device"
            openable: true
            onOpened: root.page = "input"
        }

        Text {
            topPadding: 8
            bottomPadding: 4
            text: "Apps"
            color: Theme.Colors.muted
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 12
        }
        Text {
            visible: Services.Sound.streams.length === 0
            height: 30
            verticalAlignment: Text.AlignVCenter
            text: "No apps are playing sound"
            color: Theme.Colors.muted
            font.family: Theme.Fonts.family
            font.weight: Theme.Fonts.weight
            font.pixelSize: 12
        }
        Repeater {
            model: Services.Sound.streams

            SoundLevel {
                required property var modelData
                readonly property string media: modelData.properties["media.name"] ?? ""
                node: modelData
                icon: "audio"
                mutedIcon: "audio"
                iconSource: Services.Sound.appIcon(modelData)
                what: Services.Sound.appName(modelData)
                label: media && media.toLowerCase() !== what.toLowerCase() ? what + " · " + media : what
            }
        }
    }

    NestedPage {
        id: devicePage
        x: 24 * (1 - pageSpring.value)
        width: root.width
        maximumHeight: root.maximumHeight
        opacity: pageSpring.value
        visible: opacity > 0
        enabled: root.page !== ""
        title: root.pickingInput ? "Input" : "Output"
        subtitle: Services.Sound.label(root.pickingInput ? Services.Sound.source : Services.Sound.sink) || "Nothing selected"
        backLabel: "Back to sound"
        onBackRequested: root.page = ""

        Flickable {
            id: deviceScroll
            x: -8
            width: parent.width + 16
            height: Math.min(contentHeight, devicePage.bodyMaximumHeight)
            contentWidth: width
            contentHeight: deviceList.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            interactive: false

            Components.KineticScroll {
                view: deviceScroll
            }

            Column {
                id: deviceList
                readonly property var current: root.pickingInput ? Services.Sound.source : Services.Sound.sink
                readonly property var choices: Services.Sound.devices(root.pickingInput)
                width: parent.width
                spacing: 2

                Text {
                    visible: deviceList.choices.length === 0
                    leftPadding: 12
                    text: !Pipewire.ready ? "Connecting to PipeWire" : root.pickingInput ? "No microphones" : "No output devices"
                    color: Theme.Colors.muted
                    font.family: Theme.Fonts.family
                    font.weight: Theme.Fonts.weight
                    font.pixelSize: 12
                }

                Repeater {
                    model: deviceList.choices

                    Rectangle {
                        id: choice
                        required property var modelData
                        readonly property bool selected: deviceList.current === modelData
                        readonly property string label: Services.Sound.label(modelData)

                        width: parent.width
                        height: 36
                        radius: 8
                        color: rowMouse.containsMouse || activeFocus ? Theme.Colors.highlight : Theme.Colors.transparent
                        activeFocusOnTab: true
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: label
                        Accessible.checked: selected
                        Keys.onReturnPressed: Services.Sound.select(root.pickingInput, modelData)
                        Keys.onSpacePressed: Services.Sound.select(root.pickingInput, modelData)

                        Components.Icon {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            visible: choice.selected
                            action: "check"
                        }
                        Text {
                            x: 36
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - 10
                            text: choice.label
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: choice.selected ? Theme.Colors.foreground : Theme.Colors.muted
                            font.family: Theme.Fonts.family
                            font.weight: Theme.Fonts.weight
                            font.pixelSize: 13
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.Sound.select(root.pickingInput, choice.modelData)
                        }
                        Components.Tooltip {
                            text: choice.label
                            shown: rowMouse.containsMouse && choice.label.length > 40
                        }
                    }
                }
            }
        }
    }
}
