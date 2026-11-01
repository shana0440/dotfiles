import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const geometry = vm.createContext({});
const source = readFileSync(new URL("../config/Capture/RegionGeometry.js", import.meta.url), "utf8");
vm.runInContext(source.replace(/^\.pragma library\s*/, ""), geometry);
const plain = value => JSON.parse(JSON.stringify(value));

test("dragging in either direction creates the same rectangle", () => {
  const start = { x: 100, y: 50 }, end = { x: 400, y: 300 };
  const expected = { x: 100, y: 50, width: 300, height: 250 };
  assert.deepEqual(plain(geometry.fromPoints(start, end, 800, 600)), expected);
  assert.deepEqual(plain(geometry.fromPoints(end, start, 800, 600)), expected);
});

test("dragging beyond each screen edge clips without moving the anchor", () => {
  const cases = [
    [{ x: 100, y: 100 }, { x: 1000, y: 500 }, { x: 100, y: 100, width: 700, height: 400 }],
    [{ x: 100, y: 100 }, { x: 500, y: 900 }, { x: 100, y: 100, width: 400, height: 500 }],
    [{ x: 700, y: 500 }, { x: -200, y: 100 }, { x: 0, y: 100, width: 700, height: 400 }],
    [{ x: 700, y: 500 }, { x: 100, y: -200 }, { x: 100, y: 0, width: 600, height: 500 }],
    [{ x: 100, y: 100 }, { x: 1000, y: 900 }, { x: 100, y: 100, width: 700, height: 500 }],
    [{ x: 700, y: 500 }, { x: -200, y: -100 }, { x: 0, y: 0, width: 700, height: 500 }],
  ];
  for (const [start, end, expected] of cases)
    assert.deepEqual(plain(geometry.fromPoints(start, end, 800, 600)), expected);
});

test("moving stays within the selected monitor", () => {
  const region = { x: 100, y: 50, width: 300, height: 200 };
  assert.deepEqual(plain(geometry.move(region, -1000, -1000, 800, 600)),
    { x: 0, y: 0, width: 300, height: 200 });
  assert.deepEqual(plain(geometry.move(region, 1000, 1000, 800, 600)),
    { x: 500, y: 400, width: 300, height: 200 });
});

test("resizing cannot invert a rectangle or leave the monitor", () => {
  const region = { x: 100, y: 100, width: 200, height: 120 };
  assert.deepEqual(plain(geometry.resize(region, "nw", 500, 500, 800, 600)),
    { x: 284, y: 204, width: 16, height: 16 });
  assert.deepEqual(plain(geometry.resize(region, "se", 1000, 1000, 800, 600)),
    { x: 100, y: 100, width: 700, height: 500 });
});

test("each edge changes only its own side", () => {
  const region = { x: 100, y: 100, width: 200, height: 120 };
  assert.deepEqual(plain(geometry.resize(region, "w", 20, 70, 800, 600)),
    { x: 120, y: 100, width: 180, height: 120 });
  assert.deepEqual(plain(geometry.resize(region, "n", 70, 20, 800, 600)),
    { x: 100, y: 120, width: 200, height: 100 });
});

test("global geometry preserves negative monitor origins", () => {
  const region = { x: 10, y: 20, width: 300, height: 200 };
  const text = geometry.serialize(region, { x: -1920, y: -100 });
  assert.equal(text, "-1910,-80 300x200");
  assert.deepEqual(plain(geometry.parse(text)), { x: -1910, y: -80, width: 300, height: 200 });
});

test("invalid geometry is rejected", () => {
  for (const text of ["", "10,20 0x20", "10,20 20x0", "10,20 20x20; command", "NaN,0 10x10"])
    assert.equal(geometry.parse(text), null);
});

test("recording shade clips correctly on other monitors", () => {
  assert.deepEqual(plain(geometry.intersection({ x: -20, y: -10, width: 300, height: 200 }, 800, 600)),
    { x: 0, y: 0, width: 280, height: 190 });
  const outside = geometry.intersection({ x: 900, y: 0, width: 100, height: 100 }, 800, 600);
  assert.equal(outside.width, 0);
});

test("fitting handles tiny or unconfigured surfaces", () => {
  assert.deepEqual(plain(geometry.fit({ x: 100, y: 100, width: 100, height: 100 }, 8, 8)),
    { x: 0, y: 0, width: 8, height: 8 });
});
