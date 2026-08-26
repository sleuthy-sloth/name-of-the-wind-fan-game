// _probe_body.mjs — temporary diagnostic: sample colors in the head region
// of frame 0 (down-facing) of published sheets.
import { loadPngRgba } from "./lib/png-compositor.mjs";

const SHEETS = process.argv.slice(2);
for (const path of SHEETS) {
  const png = loadPngRgba(path);
  // idle row 0 = up, row 1 = left, row 2 = down, row 3 = right; use down (y=128)
  const ox = 0, oy = 2 * 64;
  const seen = new Map();
  let opaque = 0;
  for (let y = oy; y < oy + 64; y++) {
    for (let x = ox; x < ox + 64; x++) {
      const i = (y * png.width + x) * 4;
      if (png.data[i + 3] < 128) continue;
      opaque++;
      const key = "#" + [png.data[i], png.data[i + 1], png.data[i + 2]]
        .map(v => v.toString(16).padStart(2, "0")).join("");
      seen.set(key, (seen.get(key) ?? 0) + 1);
    }
  }
  const top = [...seen.entries()].sort((a, b) => b[1] - a[1]).slice(0, 10);
  console.log("\n== " + path.split("/").pop() + " (frame down, opaque px: " + opaque + ")");
  for (const [color, count] of top) console.log("  " + color + " x" + count);
}
