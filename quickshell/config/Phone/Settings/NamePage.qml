import QtQuick
import "../../Theme" as Theme
import "../../Services" as Services

Page {
    id: page

    property string error: ""
    readonly property string draft: field.text.trim()
    readonly property bool dirty: draft !== Services.Mei.name

    function load() {
        error = ""
        field.text = Services.Mei.name
    }
    function save() {
        if (!dirty || !draft || Services.Mei.renaming) return
        error = ""
        Services.Mei.rename(draft, failure => {
            page.error = failure
            if (!failure) page.back()
        })
    }
    function focusPage() {
        field.forceActiveFocus()
        field.selectAll()
    }

    title: "Name"
    backLabel: "Settings"
    action: Services.Mei.renaming ? "Saving…" : "Save"
    actionEnabled: dirty && draft !== "" && !Services.Mei.renaming
    holdBack: dirty
    onActionTriggered: save()
    onBackHeld: discardAlert.open()

    Group {
        pt: page.pt
        Item {
            width: parent.width
            height: 50 * page.pt
            TextInput {
                id: field
                anchors { left: parent.left; right: parent.right; leftMargin: 18 * page.pt; rightMargin: 18 * page.pt; verticalCenter: parent.verticalCenter }
                color: Look.ink
                selectionColor: Qt.alpha(Look.accent, 0.4)
                selectedTextColor: Look.ink
                selectByMouse: true
                maximumLength: 40
                font { family: Theme.Fonts.family; pixelSize: 17 * page.pt }
                onAccepted: page.save()
                Keys.onEscapePressed: page.requestBack()
            }
        }
    }

    Caption {
        pt: page.pt
        note: true
        text: page.error || "The name she answers as. It is saved to config.toml and used from her next answer."
        color: page.error ? Look.destructive : Look.secondaryInk
    }

    overlays: Alert {
        id: discardAlert
        pt: page.pt
        hiddenBottom: page.hiddenBottom
        title: "Discard changes?"
        message: "Her name will stay " + Services.Mei.name + "."
        cancelLabel: "Keep editing"
        confirmLabel: "Discard"
        onDismissed: field.forceActiveFocus()
        onConfirmed: {
            page.load()
            discardAlert.close()
            page.back()
        }
    }
}
