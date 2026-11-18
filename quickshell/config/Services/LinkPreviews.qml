pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property var pages: ({})
    readonly property int pageLimit: 600000

    function firstLink(text, stillWriting) {
        const match = stillWriting ? text.match(/\]\((https?:\/\/[^)\s]+)\)/)
            : text.match(/\]\((https?:\/\/[^)\s]+)\)|(https?:\/\/[^\s<>()\]]+)/)
        return match ? match[1] || match[2] : ""
    }

    function fetch(url) {
        if (!url || url in pages) return
        remember(url, null)
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) remember(url, read(url, xhr.responseText.slice(0, pageLimit)))
        }
        xhr.open("GET", url)
        xhr.setRequestHeader("User-Agent", "Mozilla/5.0")
        xhr.send()
    }

    function remember(url, page) {
        const next = Object.assign({}, pages)
        next[url] = page
        pages = next
    }

    function decode(text) {
        return text
            .replace(/&#(\d+);/g, (match, code) => String.fromCodePoint(Number(code)))
            .replace(/&#x([0-9a-f]+);/gi, (match, code) => String.fromCodePoint(parseInt(code, 16)))
            .replace(/&quot;/g, "\"").replace(/&#39;|&apos;/g, "'")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&")
            .trim()
    }

    function attribute(tag, name) {
        const match = tag.match(new RegExp("\\s" + name + "\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)')", "i"))
        return match ? decode(match[1] ?? match[2]) : ""
    }

    function absolute(link, page) {
        if (!link || /^https?:\/\//.test(link)) return link
        const origin = page.match(/^https?:\/\/[^\/]+/)[0]
        if (link.startsWith("//")) return page.split(":")[0] + ":" + link
        if (link.startsWith("/")) return origin + link
        return page.replace(/[^\/]*$/, "") + link
    }

    function read(url, html) {
        const meta = {}
        const metaTag = /<meta\s[^>]*>/gi
        for (let found = metaTag.exec(html); found; found = metaTag.exec(html)) {
            const tag = found[0]
            const key = (attribute(tag, "property") || attribute(tag, "name")).toLowerCase()
            if (key && !(key in meta)) meta[key] = attribute(tag, "content")
        }
        const titleTag = html.match(/<title[^>]*>([^<]*)<\/title>/i)
        const page = {
            site: meta["og:site_name"] || url.match(/^https?:\/\/(?:www\.)?([^\/:]+)/)[1],
            title: meta["og:title"] || meta["twitter:title"] || (titleTag ? decode(titleTag[1]) : ""),
            description: meta["og:description"] || meta["twitter:description"] || meta["description"] || "",
            image: absolute(meta["og:image"] || meta["twitter:image"] || "", url),
        }
        return page.title || page.image ? page : null
    }
}
