import QtQuick
import "../../Theme" as Theme
import "../../Services" as Services

Page {
    id: page

    required property PageState draft
    readonly property string name: draft.text.trim()
    readonly property bool dirty: name !== Services.Mei.name

    function save() {
        if (!dirty || !name || Services.Mei.renaming) return
        const draft = page.draft
        draft.error = ""
        Services.Mei.rename(name, failure => draft.finish(failure))
    }
    function focusPage() {
        field.forceActiveFocus()
        field.selectAll()
    }

    title: "Name"
    backLabel: "Settings"
    action: Services.Mei.renaming ? "Saving…" : "Save"
    actionEnabled: dirty && name !== "" && !Services.Mei.renaming
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
                text: page.draft.text
                onTextChanged: page.draft.text = text
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
        text: page.draft.error || "The name she answers as. It is saved to config.toml and used from her next answer."
        color: page.draft.error ? Look.destructive : Look.secondaryInk
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
            page.draft.reset(Services.Mei.name)
            discardAlert.close()
            page.back()
        }
    }
}
