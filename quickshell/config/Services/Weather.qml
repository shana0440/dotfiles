pragma Singleton
import QtQuick
import Quickshell

// Current weather from wttr.in, located by the network's public IP, so it needs no
// key or configuration. Refreshes every 20 minutes and retries a failure after one.
Singleton {
    id: root

    property bool loaded: false
    property int temperature: 0
    property int feelsLike: 0
    property int high: 0
    property int low: 0
    property string condition: ""
    property string place: ""
    property int code: 0
    property bool night: false
    // An Icon action for the current condition.
    readonly property string icon: {
        const c = code
        if ([200, 386, 389, 392, 395].includes(c))
            return "weatherStorm"
        if ([179, 182, 185, 227, 230, 317, 320, 323, 326, 329, 332, 335, 338, 350,
             362, 365, 368, 371, 374, 377].includes(c))
            return "weatherSnow"
        if ([176, 299, 302, 305, 308, 311, 314, 356, 359].includes(c))
            return "weatherRain"
        if ([263, 266, 281, 284, 293, 296, 353].includes(c))
            return "weatherDrizzle"
        if ([143, 248, 260].includes(c))
            return "weatherFog"
        if ([119, 122].includes(c))
            return "weatherCloudy"
        if (c === 116)
            return night ? "weatherPartlyNight" : "weatherPartly"
        return night ? "weatherClearNight" : "weatherClear"
    }

    property var request: null

    function refresh() {
        if (request)
            return
        const xhr = new XMLHttpRequest()
        request = xhr
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || request !== xhr)
                return
            request = null
            requestTimeout.stop()
            try {
                if (xhr.status !== 200)
                    throw new Error("HTTP " + xhr.status)
                apply(JSON.parse(xhr.responseText))
                retry.stop()
            } catch (error) {
                console.warn("Weather: " + error)
                retry.restart()
            }
        }
        // j2 is the JSON report without the hourly forecast.
        xhr.open("GET", "https://wttr.in/?format=j2")
        xhr.send()
        requestTimeout.restart()
    }

    // "06:10 AM" to minutes after midnight.
    function minutes(clock) {
        const match = /(\d+):(\d+)\s*(AM|PM)/i.exec(clock ?? "")
        if (!match)
            return -1
        return (Number(match[1]) % 12 + (match[3].toUpperCase() === "PM" ? 12 : 0)) * 60 + Number(match[2])
    }

    function apply(data) {
        const current = data.current_condition[0]
        const today = data.weather[0]
        const country = data.nearest_area?.[0]?.country?.[0]?.value ?? ""
        // Fahrenheit only where the reported place uses it; a Linux locale is too
        // often en_US regardless of where the machine is.
        const fahrenheit = ["United States of America", "Liberia", "Myanmar"].includes(country)
        const unit = fahrenheit ? "F" : "C"
        temperature = Number(current["temp_" + unit])
        feelsLike = Number(current["FeelsLike" + unit])
        high = Number(today["maxtemp" + unit])
        low = Number(today["mintemp" + unit])
        condition = current.weatherDesc?.[0]?.value?.trim() ?? ""
        place = data.nearest_area?.[0]?.areaName?.[0]?.value ?? ""
        code = Number(current.weatherCode)
        const now = new Date()
        const time = now.getHours() * 60 + now.getMinutes()
        const sunrise = minutes(today.astronomy?.[0]?.sunrise)
        const sunset = minutes(today.astronomy?.[0]?.sunset)
        night = sunrise >= 0 && sunset >= 0 && (time < sunrise || time >= sunset)
        loaded = true
    }

    Timer {
        interval: 20 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: retry
        interval: 60 * 1000
        onTriggered: root.refresh()
    }

    Timer {
        id: requestTimeout
        interval: 20 * 1000
        onTriggered: {
            const xhr = root.request
            root.request = null
            xhr?.abort()
            retry.restart()
        }
    }
}
