.pragma library

// Spreads windows over an area without overlap, keeping their reading order (top to
// bottom, left to right) like Mission Control. Each window keeps its aspect ratio;
// one shared scale fits every row, never above `maxScale`. Returns one rect per
// input window, in input order.
function spread(windows, area, gap, maxScale) {
    const count = windows.length
    if (!count) return []
    const order = windows.map((w, i) => i)
        .sort((a, b) => (windows[a].y + windows[a].height / 2) - (windows[b].y + windows[b].height / 2)
            || windows[a].x - windows[b].x)

    let best = null
    for (let rows = 1; rows <= count; rows++) {
        const perRow = Math.ceil(count / rows)
        const groups = []
        for (let i = 0; i < count; i += perRow) {
            // Each row reads left to right by the windows' own positions.
            groups.push(order.slice(i, i + perRow).sort((a, b) => windows[a].x - windows[b].x))
        }
        const rowWidths = groups.map(g => g.reduce((sum, i) => sum + windows[i].width, 0))
        const rowHeights = groups.map(g => Math.max(...g.map(i => windows[i].height)))
        const widest = Math.max(...groups.map((g, r) => rowWidths[r] / Math.max(1, area.width - gap * (g.length - 1))))
        const tallest = rowHeights.reduce((a, b) => a + b, 0) / Math.max(1, area.height - gap * (groups.length - 1))
        const scale = Math.min(maxScale, 1 / Math.max(widest, tallest))
        if (!best || scale > best.scale + 0.001) best = { scale, groups, rowHeights }
    }

    const rects = new Array(count)
    const s = best.scale
    const totalHeight = best.rowHeights.reduce((a, h) => a + h * s, 0) + gap * (best.groups.length - 1)
    let y = area.y + (area.height - totalHeight) / 2
    best.groups.forEach((group, r) => {
        const rowWidth = group.reduce((sum, i) => sum + windows[i].width * s, 0) + gap * (group.length - 1)
        let x = area.x + (area.width - rowWidth) / 2
        const rowHeight = best.rowHeights[r] * s
        for (const i of group) {
            const w = windows[i].width * s
            const h = windows[i].height * s
            rects[i] = { x: x, y: y + (rowHeight - h) / 2, width: w, height: h }
            x += w + gap
        }
        y += rowHeight + gap
    })
    return rects
}
