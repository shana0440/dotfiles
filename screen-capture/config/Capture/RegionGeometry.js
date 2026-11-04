.pragma library

var minimumSize = 16;

function clamp(value, low, high) {
    return Math.max(low, Math.min(high, value));
}

function fit(rect, width, height) {
    var w = clamp(Math.round(rect.width), Math.min(minimumSize, width), width);
    var h = clamp(Math.round(rect.height), Math.min(minimumSize, height), height);
    return {
        x: clamp(Math.round(rect.x), 0, width - w),
        y: clamp(Math.round(rect.y), 0, height - h),
        width: w,
        height: h
    };
}

function fromPoints(start, end, width, height) {
    return fit(intersection({
        x: Math.min(start.x, end.x),
        y: Math.min(start.y, end.y),
        width: Math.abs(end.x - start.x),
        height: Math.abs(end.y - start.y)
    }, width, height), width, height);
}

function move(rect, dx, dy, width, height) {
    return fit({ x: rect.x + dx, y: rect.y + dy, width: rect.width, height: rect.height }, width, height);
}

function resize(rect, edge, dx, dy, width, height) {
    var left = rect.x;
    var top = rect.y;
    var right = rect.x + rect.width;
    var bottom = rect.y + rect.height;
    if (edge.indexOf("w") !== -1) left = clamp(left + dx, 0, right - minimumSize);
    if (edge.indexOf("e") !== -1) right = clamp(right + dx, left + minimumSize, width);
    if (edge.indexOf("n") !== -1) top = clamp(top + dy, 0, bottom - minimumSize);
    if (edge.indexOf("s") !== -1) bottom = clamp(bottom + dy, top + minimumSize, height);
    return fit({ x: left, y: top, width: right - left, height: bottom - top }, width, height);
}

function intersection(rect, width, height) {
    var x = clamp(rect.x, 0, width);
    var y = clamp(rect.y, 0, height);
    return {
        x: x,
        y: y,
        width: Math.max(0, Math.min(rect.x + rect.width, width) - x),
        height: Math.max(0, Math.min(rect.y + rect.height, height) - y)
    };
}

function parse(text) {
    var match = /^(-?\d+),(-?\d+) ([1-9]\d*)x([1-9]\d*)$/.exec(text);
    return match ? { x: Number(match[1]), y: Number(match[2]), width: Number(match[3]), height: Number(match[4]) } : null;
}

function serialize(rect, screen) {
    return Math.round(screen.x + rect.x) + "," + Math.round(screen.y + rect.y)
        + " " + Math.round(rect.width) + "x" + Math.round(rect.height);
}
