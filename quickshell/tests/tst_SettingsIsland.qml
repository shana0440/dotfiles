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

    function cleanup() {
        Services.Capture.takingScreenshot = false
    }

    function test_spinner_replaces_settings_until_finished() {
        const island = createTemporaryObject(islandComponent, this)
        const settings = findChild(island, "captureControlsButton")
        const spinner = findChild(island, "screenshotSpinner")
        const animation = findChild(spinner, "spinnerAnimation")
        verify(settings.visible)
        verify(!spinner.visible)
        verify(!animation.running)
        Services.Capture.takingScreenshot = true
        verify(!settings.visible)
        verify(!settings.enabled)
        verify(spinner.visible)
        verify(animation.running)
        Services.Capture.takingScreenshot = false
        verify(settings.visible)
        verify(settings.enabled)
        verify(!spinner.visible)
        verify(!animation.running)
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
