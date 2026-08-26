// render-frame.mjs — crop one animation frame from a sheet and save it
// upscaled 6x for visual inspection.
import fs from "fs";
import { PNG } from "pngjs";
import { loadPngRgba } from "./lib/png-compositor.mjs";

// args: <sheet.png> <out.png> [col] [row] [frameSize]
const [src, out, colArg, rowArg, sizeArg] = process.argv.slice(2);
const col = parseInt(colArg ?? "0", 10);
const row = parseInt(rowArg ?? "2", 10); // idle/down by default
const size = parseInt(sizeArg ?? "64", 10);

const srcPng = loadPngRgba(src);
const scale = 6;
const dst = new PNG({ width: size * scale, height: size * scale });
for (let y = 0; y < size * scale; y++) {
  for (let x = 0; x < size * scale; x++) {
    const sx = col * size + Math.floor(x / scale);
    const sy = row * size + Math.floor(y / scale);
    const si = (sy * srcPng.width + sx) * 4;
    const di = (y * dst.width + x) * 4;
    // checkerboard background so transparency is obvious
    const checker = ((Math.floor(x / 12) + Math.floor(y / 12)) % 2) === 0;
    dst.data[di] = checker ? 200 : 160;
    dst.data[di + 1] = checker ? 200 : 170;
    dst.data[di + 2] = checker ? 200 : 160;
    dst.data[di + 3] = 255;
    if (srcPng.data[si + 3] > 0) {
      const alpha = srcPng.data[si + 3] / 255;
      for (let c = 0; c < 3; c++) {
        dst.data[di + c] = Math.round(dst.data[di + c] * (1 - alpha) + srcPng.data[si + c] * alpha);
      }
    }
  }
}
fs.writeFileSync(out, PNG.sync.write(dst));
console.log("wrote", out);
