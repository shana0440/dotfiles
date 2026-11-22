import QtQuick

Item {
    id: root

    property list<Item> views
    property Item activeView: null
    property int alignment: Qt.AlignHCenter

    Repeater {
        model: root.views

        delegate: ViewReveal {
            id: viewContainer
            required property var modelData
            view: modelData
            current: root.activeView === view
            alignment: root.alignment

            Component.onCompleted: view.parent = viewContainer
        }
    }
}
