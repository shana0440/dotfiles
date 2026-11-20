.pragma library

function escapeHtml(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}

function formatInline(text, codeStyle, linkColor) {
    const tokens = /\\[\\`]|`+|\[([^\]\n]+)\]\(([^)\s]+)\)|(https?:\/\/[^\s<>()\]]+)/g
    const backticks = /`+/g
    let result = ""
    let offset = 0
    let token
    while ((token = tokens.exec(text)) !== null) {
        const [match, label, target, bare] = token
        let markup
        if (match.startsWith("`")) {
            backticks.lastIndex = tokens.lastIndex
            let end
            do { end = backticks.exec(text) } while (end && end[0].length !== match.length)
            if (!end) continue
            let code = text.slice(tokens.lastIndex, end.index).replace(/\n/g, " ")
            if (code.startsWith(" ") && code.endsWith(" ") && code.trim()) code = code.slice(1, -1)
            markup = '\u200b<span style="' + codeStyle + '">' + escapeHtml(code) + '</span>'
            tokens.lastIndex = backticks.lastIndex
        } else if (target || bare) {
            markup = '<a href="' + escapeHtml(target || bare) + '"><span style="color: '
                + linkColor + '">' + escapeHtml(label || bare) + '</span></a>'
        } else continue
        result += text.slice(offset, token.index) + markup
        offset = tokens.lastIndex
    }
    return result + text.slice(offset)
}

function format(text, codeFont, codeSize, codeFill, codeInk, linkColor) {
    const codeStyle = 'font-family: &quot;' + escapeHtml(codeFont) + '&quot;; font-size: ' + codeSize
        + 'px; background-color: ' + codeFill + '; color: ' + codeInk + '; white-space: pre-wrap'
    const result = []
    let paragraph = []
    let fence = ""
    function flush() {
        if (!paragraph.length) return
        result.push(formatInline(paragraph.join("\n"), codeStyle, linkColor))
        paragraph = []
    }
    for (const line of text.split("\n")) {
        const marker = /^(?:[ \t]*>[ \t]*)*[ \t]*(`{3,}|~{3,})(.*)$/.exec(line)
        if (fence) {
            result.push(line)
            if (marker && marker[1].startsWith(fence) && !marker[2].trim()) fence = ""
        } else if (marker && (marker[1][0] === "~" || !marker[2].includes("`"))) {
            flush()
            fence = marker[1]
            result.push(line)
        } else if (!line.trim()) {
            flush()
            result.push(line)
        } else {
            paragraph.push(line)
        }
    }
    flush()
    return result.join("\n")
}
