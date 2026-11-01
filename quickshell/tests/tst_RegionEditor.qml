import QtQuick
import QtQuick.Window
import QtTest
import "Capture" as Capture

TestCase {
    name: "RegionEditor"
    when: windowShown
    visible: true
    width: 800
    height: 600

    Component {
        id: sceneComponent
        Rectangle {
            width: 800
            height: 600
            color: "white"
            property alias editor: editor
            Capture.RegionEditor {
                id: editor
                anchors.fill: parent
                editing: true
                activeRegion: true
                onSelectionEdited: rectangle => region = rectangle
            }
        }
    }

    SignalSpy { id: confirmed; signalName: "confirmed" }
    SignalSpy { id: cancelled; signalName: "cancelled" }
    SignalSpy { id: edited; signalName: "selectionEdited" }

    function init() {
        confirmed.clear()
        cancelled.clear()
        edited.clear()
    }

    function selectedScene() {
        const scene = createTemporaryObject(sceneComponent, this)
        scene.editor.kind = "recording"
        scene.editor.region = { x: 100, y: 100, width: 300, height: 200 }
        return scene
    }

    function test_starts_without_selection() {
        const scene = createTemporaryObject(sceneComponent, this)
        compare(scene.editor.hasRegion, false)
        confirmed.target = scene.editor
        cancelled.target = scene.editor
        scene.editor.forceActiveFocus()
        keyClick(Qt.Key_Return)
        compare(confirmed.count, 0)
        keyClick(Qt.Key_Escape)
        compare(cancelled.count, 1)
    }

    function test_drag_creates_region() {
        const scene = createTemporaryObject(sceneComponent, this)
        mouseDrag(scene.editor, 20, 20, 200, 150)
        compare(scene.editor.region.x, 20)
        compare(scene.editor.region.y, 20)
        compare(scene.editor.region.width, 200)
        compare(scene.editor.region.height, 150)
    }

    function test_screenshot_captures_on_release_without_toolbar() {
        const scene = createTemporaryObject(sceneComponent, this)
        confirmed.target = scene.editor
        const sizeLabel = findChild(scene.editor, "regionSizeLabel")
        mousePress(scene.editor, 20, 20)
        mouseMove(scene.editor, 220, 170)
        compare(confirmed.count, 0)
        compare(findChild(scene.editor, "regionToolbar"), null)
        compare(sizeLabel.visible, true)
        compare(scene.editor.adjustable, false)
        compare(findChild(scene.editor, "recordRegionButton").visible, false)
        mouseRelease(scene.editor, 220, 170)
        compare(confirmed.count, 1)
        compare(scene.editor.region.width, 200)
        compare(scene.editor.region.height, 150)
    }

    function test_recording_waits_for_confirmation() {
        const scene = createTemporaryObject(sceneComponent, this)
        scene.editor.kind = "recording"
        confirmed.target = scene.editor
        mouseDrag(scene.editor, 20, 20, 200, 150)
        compare(confirmed.count, 0)
        compare(findChild(scene.editor, "regionToolbar"), null)
        compare(findChild(scene.editor, "regionSizeLabel").visible, true)
        compare(findChild(scene.editor, "recordRegionButton").visible, true)
        scene.editor.forceActiveFocus()
        keyClick(Qt.Key_Return)
        compare(confirmed.count, 1)
    }

    function test_record_button_confirms_selected_region() {
        const scene = selectedScene()
        confirmed.target = scene.editor
        const button = findChild(scene.editor, "recordRegionButton")
        verify(button.visible)
        verify(waitForPolish(scene.Window.window))
        mouseClick(button, button.width / 2, button.height / 2)
        compare(confirmed.count, 1)
    }

    function test_record_button_only_shows_after_drag() {
        const scene = createTemporaryObject(sceneComponent, this)
        scene.editor.kind = "recording"
        const button = findChild(scene.editor, "recordRegionButton")
        compare(button.visible, false)
        mousePress(scene.editor, 20, 20)
        mouseMove(scene.editor, 220, 170)
        compare(scene.editor.dragging, true)
        compare(button.visible, false)
        mouseRelease(scene.editor, 220, 170)
        compare(scene.editor.dragging, false)
        compare(button.visible, true)
        mousePress(scene.editor, 100, 100)
        compare(button.visible, false)
        mouseRelease(scene.editor, 100, 100)
        compare(button.visible, true)
    }

    function test_selection_appearance_data() {
        return [
            { tag: "screenshot", kind: "screenshot" },
            { tag: "recording", kind: "recording" }
        ]
    }

    function test_selection_appearance(data) {
        const scene = createTemporaryObject(sceneComponent, this)
        scene.editor.kind = data.kind
        const sizeLabel = findChild(scene.editor, "regionSizeLabel")
        compare(sizeLabel.visible, false)
        mousePress(scene.editor, 20, 20)
        mouseMove(scene.editor, 220, 170)
        compare(sizeLabel.visible, true)
        compare(sizeLabel.dimensions, "200 × 150")
        mouseMove(scene.editor, 260, 200)
        compare(sizeLabel.dimensions, "240 × 180")
        compare(findChild(scene.editor, "recordRegionButton").visible, false)
        compare(findChild(scene.editor, "regionToolbar"), null)
        for (const edge of ["nw", "n", "ne", "e", "se", "s", "sw", "w"]) {
            const handle = findChild(scene.editor, "selectionHandle-" + edge)
            verify(handle !== null)
            verify(handle.visible)
            compare(handle.radius, handle.width / 2)
        }
        mouseRelease(scene.editor, 260, 200)
    }

    function test_border_has_visible_dashes_and_gaps() {
        const scene = selectedScene()
        scene.update()
        verify(waitForRendering(scene))
        const image = grabImage(scene)
        const scale = Qt.application.screens[0].devicePixelRatio
        let dashes = 0
        let gaps = 0
        for (let x = 110; x < 150; x++) {
            const red = image.pixel(Math.floor(x * scale), Math.floor(99.5 * scale)).r
            if (red > 0.7) dashes++
            if (red < 0.6) gaps++
        }
        verify(dashes > 0)
        verify(gaps > 0)
    }

    function test_drag_inside_moves_region() {
        const scene = selectedScene()
        mouseDrag(scene.editor, 150, 150, 40, 30)
        compare(scene.editor.region.x, 140)
        compare(scene.editor.region.y, 130)
        compare(scene.editor.region.width, 300)
    }

    function test_corner_handle_resizes_region() {
        const scene = selectedScene()
        mouseDrag(scene.editor, 100, 100, -50, -30)
        compare(scene.editor.region.x, 50)
        compare(scene.editor.region.y, 70)
        compare(scene.editor.region.width, 350)
        compare(scene.editor.region.height, 230)
    }

    function test_keyboard_confirm_and_cancel() {
        const scene = selectedScene()
        confirmed.target = scene.editor
        cancelled.target = scene.editor
        scene.editor.forceActiveFocus()
        keyClick(Qt.Key_Return)
        compare(confirmed.count, 1)
        keyClick(Qt.Key_Escape)
        compare(cancelled.count, 1)
    }

    function test_recording_has_clear_pixels_and_no_editing() {
        const scene = createTemporaryObject(sceneComponent, this)
        scene.editor.editing = false
        scene.editor.region = { x: 101, y: 101, width: 301, height: 201 }
        edited.target = scene.editor
        mouseDrag(scene.editor, 150, 150, 30, 30)
        compare(edited.count, 0)
        compare(findChild(scene.editor, "regionSizeLabel").visible, false)
        compare(findChild(scene.editor, "selectionHandle-nw"), null)
        scene.update()
        verify(waitForRendering(scene))
        const image = grabImage(scene)
        const scale = Qt.application.screens[0].devicePixelRatio
        verify(image.pixel(Math.floor(101 * scale), Math.floor(101 * scale)).r > 0.99)
        verify(image.pixel(Math.floor(400 * scale), Math.floor(300 * scale)).r > 0.99)
        verify(image.pixel(Math.floor(20 * scale), Math.floor(20 * scale)).r < 0.6)
    }
}
