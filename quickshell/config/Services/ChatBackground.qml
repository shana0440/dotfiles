pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string defaultImage: Qt.resolvedUrl("../Phone/backgrounds/default.jpg")
    readonly property string customImage: saved.custom
    readonly property bool usingCustom: saved.useCustom && saved.custom !== ""
    readonly property string image: usingCustom ? customImage : defaultImage
    readonly property bool choosing: picker.running
    readonly property string error: picker.error

    function useDefault() { saved.useCustom = false }
    function useCustom() {
        if (saved.custom) saved.useCustom = true
        else picker.open()
    }
    function choose() { picker.open() }

    FileView {
        path: Quickshell.statePath("chat-background.json")
        blockLoading: true
        watchChanges: false
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: saved
            property string custom: ""
            property bool useCustom: false
        }
    }

    ImagePicker {
        id: picker
        title: "Choose a chat background"
        onPicked: uri => {
            saved.custom = uri
            saved.useCustom = true
        }
    }
}
