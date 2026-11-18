import QtQuick
import "../../Theme" as Theme
import "../../Services" as Services

Page {
    id: editor

    readonly property bool dirty: document.text !== Services.Mei.character

    function save() {
        Services.Mei.saveCharacter(document.text)
        back()
    }
    function load() {
        document.text = Services.Mei.character
        document.cursorPosition = 0
    }

    title: "CHARACTER.md"
    backLabel: "Settings"
    action: "Save"
    actionEnabled: dirty
    holdBack: dirty
    topPadding: 16 * pt
    onActionTriggered: save()
    onBackHeld: discardAlert.open()

    Group {
        pt: editor.pt
        TextEdit {
            id: document
            width: parent.width
            height: Math.max(implicitHeight, editor.height * 0.6)
            padding: 14 * editor.pt
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            selectByMouse: true
            color: Look.ink
            selectionColor: Qt.alpha(Look.accent, 0.3)
            selectedTextColor: Look.ink
            font { family: Theme.Fonts.mono; pixelSize: 14 * editor.pt }
            onCursorRectangleChanged: if (activeFocus) editor.reveal(document, cursorRectangle)
            Keys.onEscapePressed: editor.requestBack()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_S && event.modifiers & Qt.ControlModifier && editor.dirty) {
                    editor.save()
                    event.accepted = true
                }
            }
        }
    }

    Caption {
        pt: editor.pt
        note: true
        text: "Sets " + Services.Mei.name + "'s language, tone and speaking style. It is read for every answer, so a saved change applies to the next message."
    }

    overlays: Alert {
        id: discardAlert
        pt: editor.pt
        hiddenBottom: editor.hiddenBottom
        title: "Discard changes?"
        message: "Your edits to CHARACTER.md will be lost."
        cancelLabel: "Keep editing"
        confirmLabel: "Discard"
        onDismissed: document.forceActiveFocus()
        onConfirmed: {
            editor.load()
            discardAlert.close()
            editor.back()
        }
    }
}
