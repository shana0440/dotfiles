import QtQuick
import QtTest
import "Bar" as Bar
import "Services" as Services

TestCase {
    name: "SettingsIsland"
    when: windowShown
    visible: true
    width: 100
    height: 100

    Component {
        id: islandComponent
        Bar.SettingsIsland {}
    }

    SignalSpy { id: clicks; signalName: "clicked" }

    function cleanup() {
        Services.Capture.takingScreenshot = false
        clicks.target = null
        clicks.clear()
    }

    function test_spinner_replaces_settings_until_finished() {
        const island = createTemporaryObject(islandComponent, this)
        const indicator = findChild(island, "captureIndicator")
        compare(indicator.item.objectName, "captureControlsButton")
        verify(indicator.item.visible)
        Services.Capture.takingScreenshot = true
        compare(indicator.item.objectName, "screenshotLoadingContent")
        const spinner = findChild(indicator.item, "screenshotSpinner")
        verify(spinner.visible)
        verify(findChild(spinner, "spinnerAnimation").running)
        Services.Capture.takingScreenshot = false
        compare(indicator.item.objectName, "captureControlsButton")
        verify(indicator.item.visible)
        verify(indicator.item.enabled)
    }

    function test_settings_button_still_responds_after_loading() {
        const island = createTemporaryObject(islandComponent, this)
        const indicator = findChild(island, "captureIndicator")
        clicks.target = island
        indicator.item.clicked()
        compare(clicks.count, 1)
        Services.Capture.takingScreenshot = true
        Services.Capture.takingScreenshot = false
        indicator.item.clicked()
        compare(clicks.count, 2)
    }

    function test_repeated_transitions_never_overlay_icon_and_spinner() {
        const island = createTemporaryObject(islandComponent, this)
        const indicator = findChild(island, "captureIndicator")
        for (let i = 0; i < 10; i++) {
            Services.Capture.takingScreenshot = true
            compare(indicator.item.objectName, "screenshotLoadingContent")
            compare(indicator.children.filter(item => item.visible).length, 1)
            Services.Capture.takingScreenshot = false
            compare(indicator.item.objectName, "captureControlsButton")
            compare(indicator.children.filter(item => item.visible).length, 1)
        }
    }

    function test_loading_unmerges_immediately() {
        const island = createTemporaryObject(islandComponent, this)
        island.merged = true
        tryCompare(island, "opacity", 0)
        Services.Capture.takingScreenshot = true
        island.merged = false
        compare(island.opacity, 1)
        verify(findChild(island, "screenshotSpinner").visible)
    }

    function test_hidden_spinner_does_not_animate() {
        const island = createTemporaryObject(islandComponent, this)
        Services.Capture.takingScreenshot = true
        island.visible = false
        verify(!findChild(island, "spinnerAnimation").running)
    }
}
