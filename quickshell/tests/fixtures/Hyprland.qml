pragma Singleton
import QtQuick

QtObject {
    property var focusedWorkspace: ({ id: 1 })
    property var requests: []

    function dispatch(request) {
        requests = requests.concat([request])
        const focus = /^hl\.dsp\.focus\(\{\s*workspace\s*=\s*(\d+)\s*\}\)$/.exec(request)
        if (focus)
            focusedWorkspace = { id: Number(focus[1]) }
    }
}
